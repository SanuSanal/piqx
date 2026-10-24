import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:piqx/data/scores_repository.dart';
import 'package:piqx/data/stream_links.dart';
import 'package:piqx/data/matches.dart';
import 'package:piqx/main.dart';
import 'package:piqx/screens/splash_screen.dart';

import 'fakes.dart';

Widget app([ScoresRepository? repository]) => PiqxApp(
      repository: repository ?? FakeScoresRepository(),
      streams: StreamLinks(), // never loaded: no streams, so the placeholder shows
      autoRefresh: false,
      checkUpdatesOnStart: false,
    );

class _FailingRepository implements ScoresRepository {
  @override
  Future<List<Match>> fetchToday() async => throw const ScoresUnavailable();
}

Future<void> pastSplash(WidgetTester tester) async {
  await tester.pump(splashDuration);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'PiqX',
      packageName: 'com.piqx.piqx',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('splash shows for 2 seconds, then home', (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('LIVE FOOTBALL & CRICKET STREAMS'), findsOneWidget);
    expect(find.text('Explore Sports'), findsNothing);

    await tester.pump(splashDuration - const Duration(milliseconds: 100));
    expect(find.text('Explore Sports'), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Explore Sports'), findsOneWidget);
    expect(find.text('Arsenal'), findsOneWidget);
    expect(find.text('3 TODAY'), findsOneWidget);
  });

  testWidgets('cricket tab switches the match list', (tester) async {
    await tester.pumpWidget(app());
    await pastSplash(tester);

    await tester.tap(find.text('Cricket').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('England'), findsOneWidget);
    expect(find.text('Arsenal'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == 'Batting'), findsOneWidget);
    expect(find.text('168/4'), findsOneWidget);
    expect(find.text('17.2 ov'), findsOneWidget);
    expect(find.text('Watch Live'), findsNothing);
  });

  testWidgets('league chip filters the list; tapping it again clears the filter', (tester) async {
    await tester.pumpWidget(app());
    await pastSplash(tester);
    expect(find.text('Arsenal'), findsOneWidget);
    expect(find.text('Barcelona'), findsOneWidget);

    await tester.tap(find.text('La Liga'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Barcelona'), findsOneWidget);
    expect(find.text('Arsenal'), findsNothing);

    await tester.tap(find.text('La Liga'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Arsenal'), findsOneWidget);
    expect(find.text('Barcelona'), findsOneWidget);
  });

  testWidgets('watch live opens the stream screen', (tester) async {
    await tester.pumpWidget(app());
    await pastSplash(tester);

    await tester.tap(find.text('Watch Live').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Football Streams'), findsNWidgets(2));
  });

  testWidgets('sport card opens the stream screen for that sport', (tester) async {
    await tester.pumpWidget(app());
    await pastSplash(tester);

    await tester.tap(find.text('Cricket').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Cricket Streams'), findsNWidgets(2));
  });

  testWidgets('quiet day shows an empty state', (tester) async {
    await tester.pumpWidget(app(FakeScoresRepository(const [])));
    await pastSplash(tester);

    expect(find.text('No football today'), findsOneWidget);
    expect(find.text('0 TODAY'), findsNWidgets(2));
  });

  testWidgets('feed failure offers a retry', (tester) async {
    await tester.pumpWidget(app(_FailingRepository()));
    await pastSplash(tester);

    expect(find.text("Couldn't load scores"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('back on home warns first, then exits on a second press', (tester) async {
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(app());
    await pastSplash(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets('back on the stream screen returns home', (tester) async {
    await tester.pumpWidget(app());
    await pastSplash(tester);

    await tester.tap(find.text('Watch Live').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Football Streams'), findsNWidgets(2));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Football Streams'), findsNothing);
    expect(find.text('Explore Sports'), findsOneWidget);
    expect(find.text('Press back again to exit'), findsNothing);
  });

  testWidgets('updates button opens the update settings', (tester) async {
    await tester.pumpWidget(app());
    await pastSplash(tester);

    await tester.tap(find.byTooltip('App updates'));
    // The LIVE badge pulses forever, so pump fixed frames instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Check for updates automatically'), findsOneWidget);
    expect(find.text('PiqX v1.0.0'), findsOneWidget);
  });
}
