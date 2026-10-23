import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:piqx/update/update_service.dart';

void main() {
  test('isNewer compares dotted versions numerically', () {
    expect(isNewer('1.0.1', '1.0.0'), isTrue);
    expect(isNewer('1.10.0', '1.9.9'), isTrue);
    expect(isNewer('2.0', '1.99.99'), isTrue);
    expect(isNewer('1.0.0', '1.0.0'), isFalse);
    expect(isNewer('1.0.0', '1.0.1'), isFalse);
    expect(isNewer('1.2.0+7', '1.2.0'), isFalse);
  });

  test('parseRelease picks the APK asset and strips the v', () {
    final r = parseRelease({
      'tag_name': 'v1.3.0',
      'body': 'Live scores',
      'html_url': 'https://github.com/SanuSanal/piqx/releases/tag/v1.3.0',
      'assets': [
        {'name': 'checksums.txt', 'browser_download_url': 'https://example.com/checksums.txt'},
        {'name': 'piqx-v1.3.0.apk', 'browser_download_url': 'https://example.com/piqx-v1.3.0.apk'},
      ],
    })!;
    expect(r.version, '1.3.0');
    expect(r.apkUrl.toString(), 'https://example.com/piqx-v1.3.0.apk');
    expect(r.notes, 'Live scores');
  });

  test('parseRelease ignores releases without an APK', () {
    expect(parseRelease({'tag_name': 'v1.0.0', 'assets': []}), isNull);
  });

  test('latestRelease reads the GitHub API and treats 404 as no releases', () async {
    final found = UpdateService(
      client: MockClient((req) async {
        expect(req.url.toString(), 'https://api.github.com/repos/SanuSanal/piqx/releases/latest');
        return http.Response(
          jsonEncode({
            'tag_name': 'v2.0.0',
            'assets': [
              {'name': 'piqx-v2.0.0.apk', 'browser_download_url': 'https://example.com/a.apk'},
            ],
          }),
          200,
        );
      }),
    );
    expect((await found.latestRelease())!.version, '2.0.0');

    final none = UpdateService(client: MockClient((_) async => http.Response('', 404)));
    expect(await none.latestRelease(), isNull);
  });
}
