import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:piqx/data/matches.dart';
import 'package:piqx/data/stream_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('only http(s) links count', () {
    final links = parseStreamLinks(
      '{"football": " https://example.com/football ", "cricket": "javascript:alert(1)"}',
    );
    expect(links, {Sport.football: 'https://example.com/football'});
    expect(parseStreamLinks('{"football": null, "cricket": ""}'), isEmpty);
  });

  test('loads from Pages and keeps the links for next time', () async {
    Uri? requested;
    final online = StreamLinks(
      client: MockClient((req) async {
        requested = req.url;
        return http.Response(
          '{"football": "https://example.com/f", "cricket": "https://example.com/c",'
          ' "block": {"redirectsToOtherSites": true, "apiCalls": [{"host": "example.com"}]}}',
          200,
        );
      }),
    );
    await online.load();
    expect(requested!.path, '/piqx/streams.json');
    expect(online[Sport.football], 'https://example.com/f');
    expect(online[Sport.cricket], 'https://example.com/c');
    expect(online.blockRules.redirectsToOtherSites, isTrue);
    expect(online.blockRules.apiCalls.single.host, 'example.com');

    final offline = StreamLinks(client: MockClient((_) async => throw http.ClientException('offline')));
    await offline.load();
    expect(offline[Sport.football], 'https://example.com/f');
    expect(offline.blockRules.redirectsToOtherSites, isTrue);
  });

  test('a broken file keeps the saved links', () async {
    SharedPreferences.setMockInitialValues({'streams.json': '{"cricket": "https://example.com/c"}'});
    final links = StreamLinks(client: MockClient((_) async => http.Response('<html>oops', 200)));
    await links.load();
    expect(links[Sport.cricket], 'https://example.com/c');
    expect(links[Sport.football], isNull);
  });
}
