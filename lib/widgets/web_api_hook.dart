import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

/// An API call a web page made with `fetch` or `XMLHttpRequest`, reported by [watchApiCalls].
class WebApiCall {
  const WebApiCall({
    required this.kind,
    required this.method,
    required this.url,
    required this.status,
    required this.pageUrl,
    this.durationMs,
    this.msSinceInteraction,
    this.body,
    this.truncated = false,
    this.error,
  });

  /// `fetch` or `xhr`.
  final String kind;
  final String method;
  final String url;

  /// HTTP status; 0 when the request failed before a response.
  final int status;

  /// The page that made the call.
  final String pageUrl;
  final int? durationMs;

  /// Time from the user's last tap or key press to the call starting; null before any.
  final int? msSinceInteraction;

  /// Text response (JSON, text, XML), cut to the first 64 KB; null for other content.
  final String? body;
  final bool truncated;

  /// Why a request failed, when it did.
  final String? error;

  /// Calls that start this soon after a tap or key press count as the user's doing.
  static const interactionWindow = Duration(seconds: 2);

  /// Most likely triggered by the user rather than by the page loading on its own.
  bool get fromInteraction {
    final ms = msSinceInteraction;
    return ms != null && ms >= 0 && ms <= interactionWindow.inMilliseconds;
  }

  /// Reads one report from [apiCallHookJs]; null when it isn't one.
  static WebApiCall? fromMessage(String message) {
    try {
      final j = jsonDecode(message);
      if (j is! Map) return null;
      final url = j['url'], method = j['method'], kind = j['kind'];
      if (url is! String || method is! String || kind is! String) return null;
      int? whole(Object? v) => v is num ? v.round() : null;
      return WebApiCall(
        kind: kind,
        method: method,
        url: url,
        status: whole(j['status']) ?? 0,
        pageUrl: j['page'] as String? ?? '',
        durationMs: whole(j['ms']),
        msSinceInteraction: whole(j['sinceInteraction']),
        body: j['body'] as String?,
        truncated: j['truncated'] == true,
        error: j['error'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

typedef WebApiCallback = void Function(WebApiCall call);

const _channel = 'PiqxApi';

/// Sends the API calls of pages in [controller] to [onCall]. Register before loading the page,
/// then inject [apiCallHookJs] as each page loads.
Future<void> watchApiCalls(WebViewController controller, WebApiCallback onCall) => controller.addJavaScriptChannel(
      _channel,
      onMessageReceived: (message) {
        final call = WebApiCall.fromMessage(message.message);
        if (call != null) onCall(call);
      },
    );

/// Page script: wraps `fetch` and `XMLHttpRequest` to report each call (method, URL, status,
/// timing, and text responses up to 64 KB) through the [watchApiCalls] channel. It also notes
/// the time of the user's last tap or key press, so calls can be told apart from page loading.
/// Installs once per page; does nothing unless the channel is registered.
const apiCallHookJs = r'''
(() => {
  if (window.__piqxApiHook || !window.PiqxApi) return;
  window.__piqxApiHook = true;
  const MAX_BODY = 65536;
  let lastInteraction = null;
  for (const type of ['pointerdown', 'keydown']) {
    addEventListener(type, () => { lastInteraction = Date.now(); }, true);
  }
  const textual = (type) => /json|text|xml|javascript|graphql/i.test(type || '');
  const absolute = (url) => { try { return new URL(String(url), location.href).href; } catch (_) { return String(url); } };
  const report = (call) => {
    call.page = location.href;
    call.sinceInteraction = lastInteraction === null ? null : call.start - lastInteraction;
    try { PiqxApi.postMessage(JSON.stringify(call)); } catch (_) {}
  };
  const withBody = (call, body) => {
    if (typeof body === 'string') {
      call.body = body.slice(0, MAX_BODY);
      call.truncated = body.length > MAX_BODY;
    }
    return call;
  };

  const nativeFetch = window.fetch;
  if (nativeFetch) {
    window.fetch = function (input, init) {
      const start = Date.now();
      const method = String((init && init.method) || (input && input.method) || 'GET').toUpperCase();
      const url = absolute(typeof input === 'string' || input instanceof URL ? input : input && input.url);
      const result = nativeFetch.apply(this, arguments);
      result.then((res) => {
        const call = { kind: 'fetch', method, url, status: res.status, start, ms: Date.now() - start };
        if (!textual(res.headers.get('content-type'))) return report(call);
        res.clone().text().then((body) => report(withBody(call, body)), () => report(call));
      }, (error) => report({ kind: 'fetch', method, url, status: 0, start, ms: Date.now() - start, error: String(error) }));
      return result;
    };
  }

  const xhr = XMLHttpRequest.prototype;
  const open = xhr.open, send = xhr.send;
  xhr.open = function (method, url) {
    this.__piqxCall = { kind: 'xhr', method: String(method || 'GET').toUpperCase(), url: absolute(url) };
    return open.apply(this, arguments);
  };
  xhr.send = function () {
    const call = this.__piqxCall;
    if (call) {
      call.start = Date.now();
      this.addEventListener('loadend', () => {
        call.status = this.status;
        call.ms = Date.now() - call.start;
        try {
          const type = this.responseType;
          if ((type === '' || type === 'text') && textual(this.getResponseHeader('content-type'))) withBody(call, this.responseText);
          else if (type === 'json') withBody(call, JSON.stringify(this.response));
        } catch (_) {}
        report(call);
      });
    }
    return send.apply(this, arguments);
  };
})();
''';
