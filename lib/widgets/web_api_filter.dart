import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import '../data/block_rules.dart';

const _channel = 'PiqxBlocked';

/// Sends the address of each call [apiFilterJs] blocks in [controller] to [onBlocked]. Register
/// before loading the page.
Future<void> watchBlockedApiCalls(WebViewController controller, void Function(String url) onBlocked) =>
    controller.addJavaScriptChannel(_channel, onMessageReceived: (message) => onBlocked(message.message));

/// Page script: blocks the API calls that match any of [rules]. Blocked calls made with `fetch`
/// fail as a network error would, `XMLHttpRequest` ones end with an `error` event and status 0,
/// and `sendBeacon` ones are refused; nothing reaches the network. Every other call goes
/// through untouched. Each blocked call is reported through the [watchBlockedApiCalls]
/// channel, when it is registered. Inject it before `apiCallHookJs` so the hook reports
/// blocked calls as failed ones. Installs once per page.
String apiFilterJs(List<ApiBlockRule> rules) => _apiFilterJs.replaceFirst('RULES', jsonEncode(rules));

const _apiFilterJs = r'''
(() => {
  if (window.__piqxApiFilter) return;
  window.__piqxApiFilter = true;
  const rules = RULES;
  const matches = (rule, u) => {
    const host = u.hostname.toLowerCase();
    if (rule.host && host !== rule.host && !host.endsWith('.' + rule.host)) return false;
    return Object.entries(rule.query).every(([name, value]) => u.searchParams.getAll(name).includes(value));
  };
  const blocked = (url) => {
    let u;
    try {
      u = new URL(String(url), location.href);
    } catch (_) {
      return false;
    }
    if (!rules.some((rule) => matches(rule, u))) return false;
    try { window.PiqxBlocked && PiqxBlocked.postMessage(u.href); } catch (_) {}
    return true;
  };

  const nativeFetch = window.fetch;
  if (nativeFetch) {
    window.fetch = function (input, init) {
      const url = typeof input === 'string' || input instanceof URL ? input : input && input.url;
      if (blocked(url)) return Promise.reject(new TypeError('Blocked by PiqX: ' + url));
      return nativeFetch.apply(this, arguments);
    };
  }

  const xhr = XMLHttpRequest.prototype;
  const open = xhr.open, send = xhr.send;
  xhr.open = function (method, url) {
    this.__piqxUrl = url;
    return open.apply(this, arguments);
  };
  xhr.send = function () {
    if (!blocked(this.__piqxUrl)) return send.apply(this, arguments);
    setTimeout(() => {
      Object.defineProperty(this, 'readyState', { configurable: true, value: 4 });
      for (const type of ['readystatechange', 'error', 'loadend']) {
        this.dispatchEvent(type === 'readystatechange' ? new Event(type) : new ProgressEvent(type));
      }
    });
  };

  if (navigator.sendBeacon) {
    const beacon = navigator.sendBeacon.bind(navigator);
    navigator.sendBeacon = (url, data) => (blocked(url) ? false : beacon(url, data));
  }
})();
''';
