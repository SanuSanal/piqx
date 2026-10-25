import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piqx/theme/app_theme.dart';
import 'package:piqx/widgets/toast.dart';

void main() {
  Future<BuildContext> pumpApp(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: Scaffold(
        body: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }),
      ),
    ));
    return context;
  }

  testWidgets('shows the message with the icon for its kind', (tester) async {
    final context = await pumpApp(tester);
    showToast(context, 'Saved', kind: ToastKind.success);
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('a new toast replaces the one showing', (tester) async {
    final context = await pumpApp(tester);
    showToast(context, 'First');
    await tester.pump();
    showToast(context, 'Second', kind: ToastKind.error);
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('goes away after its duration', (tester) async {
    final context = await pumpApp(tester);
    showToast(context, 'Brief', duration: const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Brief'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Brief'), findsNothing);
  });
}
