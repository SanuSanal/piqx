import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:piqx/widgets/web_api_hook.dart';

void main() {
  test('reads a fetch report from the page script', () {
    final call = WebApiCall.fromMessage(jsonEncode({
      'kind': 'fetch',
      'method': 'POST',
      'url': 'https://m.youtube.com/youtubei/v1/browse',
      'status': 200,
      'start': 1000,
      'ms': 182,
      'page': 'https://m.youtube.com/@LaLiga/videos',
      'sinceInteraction': 140,
      'body': '{"items":[]}',
      'truncated': false,
    }))!;
    expect(call.kind, 'fetch');
    expect(call.method, 'POST');
    expect(call.status, 200);
    expect(call.durationMs, 182);
    expect(call.body, '{"items":[]}');
    expect(call.fromInteraction, isTrue);
  });

  test('calls long after the last tap, or before any, are not from interaction', () {
    WebApiCall call(Object? since) => WebApiCall.fromMessage(jsonEncode(
        {'kind': 'xhr', 'method': 'GET', 'url': 'https://example.com/a', 'status': 200, 'sinceInteraction': since}))!;
    expect(call(5000).fromInteraction, isFalse);
    expect(call(null).fromInteraction, isFalse);
  });

  test('anything else on the channel is ignored', () {
    expect(WebApiCall.fromMessage('not json'), isNull);
    expect(WebApiCall.fromMessage('[1,2]'), isNull);
    expect(WebApiCall.fromMessage('{"url": "https://example.com"}'), isNull);
  });
}
