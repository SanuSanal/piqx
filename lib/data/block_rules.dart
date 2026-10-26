/// What the stream screen blocks, read from the `"block"` section of `streams.json`:
///
/// ```json
/// "block": {
///   "redirectsToOtherSites": true,
///   "apiCalls": [
///     {"host": "youtube.com", "query": {"xbot": "3"}}
///   ]
/// }
/// ```
///
/// Missing, malformed or unknown parts block nothing, so the links still load.
class BlockRules {
  const BlockRules({this.redirectsToOtherSites = false, this.apiCalls = const []});

  static const none = BlockRules();

  /// Stops the stream page from leaving its own site; see [sameSite].
  final bool redirectsToOtherSites;

  /// API calls the page may not make.
  final List<ApiBlockRule> apiCalls;

  /// Reads the `"block"` section of [data], the decoded `streams.json`.
  factory BlockRules.fromJson(Object? data) {
    final block = data is Map ? data['block'] : null;
    if (block is! Map) return none;
    final calls = block['apiCalls'];
    return BlockRules(
      redirectsToOtherSites: block['redirectsToOtherSites'] == true,
      apiCalls: [
        if (calls is List)
          for (final rule in calls.map(ApiBlockRule.fromJson)) ?rule,
      ],
    );
  }

  /// Whether a stream page that started at [start] may not go to [to]. Only addresses on
  /// another site, or that aren't web pages at all (`intent:` and the like), are blocked.
  bool blocksNavigation(Uri start, Uri to) =>
      redirectsToOtherSites && (!(to.isScheme('https') || to.isScheme('http')) || !sameSite(start.host, to.host));
}

/// An API call to block: one whose host is [host] or a subdomain of it, and whose query has
/// every parameter in [query] with that value. A rule needs at least one of the two.
class ApiBlockRule {
  const ApiBlockRule({this.host, this.query = const {}});

  /// Lowercase, without a leading dot; null matches any host.
  final String? host;
  final Map<String, String> query;

  /// Reads `{"host": "youtube.com", "query": {"xbot": "3"}}`; null when it isn't a usable rule.
  static ApiBlockRule? fromJson(Object? json) {
    if (json is! Map) return null;
    final host = json['host'], query = json['query'];
    if (host != null && host is! String) return null;
    if (query != null && query is! Map) return null;
    final h = (host as String?)?.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');
    final q = {
      for (final MapEntry(:key, :value) in (query as Map? ?? const {}).entries)
        if (key is String && (value is String || value is num)) key: '$value',
    };
    if ((h == null || h.isEmpty) && q.isEmpty) return null;
    return ApiBlockRule(host: h == null || h.isEmpty ? null : h, query: q);
  }

  Map<String, Object?> toJson() => {'host': host, 'query': query};
}

/// Whether hosts [a] and [b] are the same site: the same host, or both under the same domain
/// (its last two labels), so `www.youtube.com` and `m.youtube.com` count as one site.
bool sameSite(String a, String b) => _site(a) == _site(b);

String _site(String host) {
  host = host.toLowerCase();
  if (host.contains(':') || RegExp(r'^[\d.]+$').hasMatch(host)) return host;
  final labels = host.split('.');
  return labels.length <= 2 ? host : labels.sublist(labels.length - 2).join('.');
}
