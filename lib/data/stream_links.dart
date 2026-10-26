import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'block_rules.dart';
import 'matches.dart';

/// Stream page per sport, read from `streams.json` on the PiqX GitHub Pages site so the links
/// can change without an app release. Edit `docs/streams.json` and push to update them.
///
/// The last links fetched are kept on the device, so the stream screen still has them when
/// Pages can't be reached. A sport without a link shows the "WebView Viewport" placeholder.
/// The same file says what the stream screen blocks; see [BlockRules].
class StreamLinks {
  StreamLinks({http.Client? client, this.url = streamsJsonUrl}) : _client = client ?? http.Client();

  final http.Client _client;
  final String url;

  static const _cacheKey = 'streams.json';

  Map<Sport, String> _links = const {};
  BlockRules _blockRules = BlockRules.none;

  String? operator [](Sport sport) => _links[sport];

  BlockRules get blockRules => _blockRules;

  /// Throws, keeping what is in use, when [json] isn't a usable file.
  void _apply(String json) {
    final links = parseStreamLinks(json);
    _blockRules = BlockRules.fromJson(jsonDecode(json));
    _links = links;
  }

  /// Applies the saved links, then fetches fresh ones. Never throws: on failure the
  /// saved links stay in use.
  Future<void> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_cacheKey);
      if (saved != null) _apply(saved);
    } catch (_) {
      // No saved links yet, or storage unavailable.
    }

    try {
      // The query skips Pages' 10-minute CDN cache.
      final uri = Uri.parse(url).replace(queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'});
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final body = utf8.decode(res.bodyBytes);
      _apply(body);
      await prefs?.setString(_cacheKey, body);
    } catch (_) {
      // Offline, or the file is missing or malformed: keep what we have.
    }
  }
}

/// Reads `{"football": "https://…", "cricket": null}`. Missing, empty and non-http(s)
/// values mean no stream for that sport.
Map<Sport, String> parseStreamLinks(String json) {
  final data = jsonDecode(json);
  if (data is! Map) throw const FormatException('streams.json: expected an object');
  return {
    for (final sport in Sport.values)
      if (data[sport.name] case final String link when _isWebUrl(link)) sport: link.trim(),
  };
}

bool _isWebUrl(String link) {
  final uri = Uri.tryParse(link.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
}
