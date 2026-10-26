import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:piqx/data/block_rules.dart';

void main() {
  test('reads the block section of streams.json', () {
    final rules = BlockRules.fromJson(jsonDecode('''{
      "football": "https://www.youtube.com/@LaLiga/videos",
      "block": {
        "redirectsToOtherSites": true,
        "apiCalls": [
          {"host": " .YouTube.com ", "query": {"xbot": "3", "v": 2}},
          {"query": {"ads": "1"}},
          {"host": "example.com"}
        ]
      }
    }'''));
    expect(rules.redirectsToOtherSites, isTrue);
    expect(rules.apiCalls.map((r) => r.toJson()), [
      {'host': 'youtube.com', 'query': {'xbot': '3', 'v': '2'}},
      {'host': null, 'query': {'ads': '1'}},
      {'host': 'example.com', 'query': <String, String>{}},
    ]);
  });

  test('missing or malformed parts block nothing', () {
    expect(BlockRules.fromJson({'football': 'https://example.com'}).apiCalls, isEmpty);
    expect(BlockRules.fromJson({'block': 'yes'}).redirectsToOtherSites, isFalse);
    final rules = BlockRules.fromJson({
      'block': {
        'redirectsToOtherSites': 'true',
        'apiCalls': [
          {}, // would block every call
          {'host': ''},
          {'host': 3},
          {'query': 'xbot=3'},
          'youtube.com',
        ],
      },
    });
    expect(rules.redirectsToOtherSites, isFalse);
    expect(rules.apiCalls, isEmpty);
  });

  test('redirects may stay on the stream site only', () {
    const rules = BlockRules(redirectsToOtherSites: true);
    final start = Uri.parse('https://www.youtube.com/@LaLiga/videos');
    expect(rules.blocksNavigation(start, Uri.parse('https://m.youtube.com/@LaLiga/videos')), isFalse);
    expect(rules.blocksNavigation(start, Uri.parse('https://consent.youtube.com/m')), isFalse);
    expect(rules.blocksNavigation(start, Uri.parse('https://example.com/win')), isTrue);
    expect(rules.blocksNavigation(start, Uri.parse('https://youtube.com.evil.io/')), isTrue);
    expect(rules.blocksNavigation(start, Uri.parse('intent://www.youtube.com/watch#Intent;end')), isTrue);
    expect(BlockRules.none.blocksNavigation(start, Uri.parse('https://example.com/win')), isFalse);
  });
}
