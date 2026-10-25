import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:piqx/theme/app_theme.dart';
import 'package:piqx/update/update_prompt.dart';
import 'package:piqx/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'PiqX',
      packageName: 'com.piqx.piqx',
      version: '1.0.0',
      buildNumber: '10000',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a new version is announced without the release notes', (tester) async {
    final service = UpdateService(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'tag_name': 'v9.9.9',
              'body': '**Full Changelog**: https://github.com/SanuSanal/piqx/compare/v1.0.0...v9.9.9',
              'assets': [
                {'name': 'piqx-v9.9.9.apk', 'browser_download_url': 'https://example.com/piqx-v9.9.9.apk'},
              ],
            }),
            200,
          )),
    );
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

    // The release lookup is real async work (HTTP mock, platform channels), so let it run
    // outside the test's fake clock until the dialog is up.
    await tester.runAsync(() async {
      checkForUpdates(context, service, manual: true);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('A new version of PiqX (v9.9.9) is ready to install.'), findsOneWidget);
    expect(find.textContaining('Changelog'), findsNothing);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
  });
}
