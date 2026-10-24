import 'dart:convert';

import 'package:http/http.dart' as http;

import 'matches.dart';

/// Source of today's matches for the home screen.
abstract class ScoresRepository {
  Future<List<Match>> fetchToday();
}

/// A football competition PiqX follows, in display priority order.
class FootballCompetition {
  const FootballCompetition(this.slug, this.label, [this.tone = LeagueTone.muted]);

  /// ESPN league slug, e.g. `eng.1`.
  final String slug;
  final String label;
  final LeagueTone tone;
}

const footballCompetitions = <FootballCompetition>[
  FootballCompetition('uefa.champions', 'Champions League', LeagueTone.secondary),
  FootballCompetition('eng.1', 'Premier League', LeagueTone.neutral),
  FootballCompetition('esp.1', 'La Liga'),
  FootballCompetition('ita.1', 'Serie A'),
  FootballCompetition('ger.1', 'Bundesliga'),
  FootballCompetition('fra.1', 'Ligue 1'),
  FootballCompetition('uefa.europa', 'Europa League', LeagueTone.secondary),
  FootballCompetition('esp.copa_del_rey', 'Copa del Rey'),
];

/// Men's international sides whose matches PiqX shows (ICC top ten).
const topCricketNations = {
  'India',
  'Australia',
  'England',
  'South Africa',
  'New Zealand',
  'Pakistan',
  'Sri Lanka',
  'West Indies',
  'Bangladesh',
  'Afghanistan',
};

/// High-profile men's franchise leagues, matched against ESPN league names, with their pill label.
const majorCricketLeagues = {
  'Indian Premier League': 'IPL',
  'Big Bash League': 'BBL',
  'Pakistan Super League': 'PSL',
  'The Hundred': 'The Hundred',
  'SA20': 'SA20',
  'Caribbean Premier League': 'CPL',
  'International League T20': 'ILT20',
  'Major League Cricket': 'MLC',
};

const _internationalFormats = {'Test', 'ODI', 'T20I'};

/// Scores from ESPN's public scoreboard feeds (no API key).
///
/// Football: one scoreboard request per competition per UTC date that overlaps the local day.
/// Cricket: the global score panel, filtered to [topCricketNations] internationals and
/// [majorCricketLeagues].
class EspnScoresRepository implements ScoresRepository {
  EspnScoresRepository({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  static const _base = 'https://site.api.espn.com/apis/site/v2/sports';

  final http.Client _client;
  final DateTime Function() _clock;

  @override
  Future<List<Match>> fetchToday() async {
    final now = _clock();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final utcDates = {_ymd(dayStart.toUtc()), _ymd(dayEnd.subtract(const Duration(minutes: 1)).toUtc())};

    var failures = 0;
    Future<Map<String, dynamic>?> get(String url) async {
      try {
        final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode}', Uri.parse(url));
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        failures++;
        return null;
      }
    }

    final footballRequests = [
      for (final (i, comp) in footballCompetitions.indexed)
        for (final date in utcDates) (i, comp, get('$_base/soccer/${comp.slug}/scoreboard?dates=$date')),
    ];
    final cricketRequest = get('$_base/cricket/scorepanel');
    await Future.wait([...footballRequests.map((r) => r.$3), cricketRequest]);
    if (failures == footballRequests.length + 1) {
      throw const ScoresUnavailable();
    }

    bool isToday(DateTime start, String state) =>
        state == 'in' || (!start.isBefore(dayStart) && start.isBefore(dayEnd));

    final football = <String, RankedMatch>{};
    for (final (priority, comp, request) in footballRequests) {
      final body = await request;
      final logo = leagueLogo(body);
      for (final e in (body?['events'] as List? ?? const [])) {
        final parsed = parseFootballEvent(e as Map<String, dynamic>, comp, now, leagueLogo: logo);
        if (parsed != null && isToday(parsed.startTime!, _state(e))) {
          football[parsed.id] = RankedMatch(parsed, priority);
        }
      }
    }

    final cricket = <String, RankedMatch>{};
    for (final group in ((await cricketRequest)?['scores'] as List? ?? const [])) {
      final league = ((group as Map)['leagues'] as List?)?.firstOrNull as Map?;
      for (final e in (group['events'] as List? ?? const [])) {
        final parsed = parseCricketEvent(e as Map<String, dynamic>, league?['name'] as String? ?? '', now);
        if (parsed != null && isToday(parsed.match.startTime!, _state(e))) {
          cricket[parsed.match.id] = parsed;
        }
      }
    }

    return [..._arrange(football.values), ..._arrange(cricket.values)];
  }

  static String _ymd(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

/// Thrown when every scores request failed (offline, or the feed is down).
class ScoresUnavailable implements Exception {
  const ScoresUnavailable();

  @override
  String toString() => "Couldn't reach the live scores feed.";
}

/// A match plus its competition priority (lower sorts first).
class RankedMatch {
  const RankedMatch(this.match, this.priority);

  final Match match;
  final int priority;
}

String _state(Map e) => ((e['status'] as Map?)?['type'] as Map?)?['state'] as String? ?? 'pre';

/// Live matches first (the top one featured), then upcoming by start time, then results.
List<Match> _arrange(Iterable<RankedMatch> ranked) {
  int group(Match m) => switch (m.status) {
        MatchStatus.live => 0,
        MatchStatus.upcoming => 1,
        MatchStatus.finished => 2,
      };
  final sorted = ranked.toList()
    ..sort((a, b) {
      final g = group(a.match).compareTo(group(b.match));
      if (g != 0) return g;
      if (a.match.isLive) return a.priority.compareTo(b.priority);
      final t = a.match.startTime!.compareTo(b.match.startTime!);
      if (t != 0) return a.match.isFinished ? -t : t;
      return a.priority.compareTo(b.priority);
    });
  return [
    for (final (i, r) in sorted.indexed) i == 0 && r.match.isLive ? r.match.copyWith(featured: true) : r.match,
  ];
}

/// The competition's standard logo from a soccer scoreboard response.
String? leagueLogo(Map<String, dynamic>? scoreboard) {
  final league = (scoreboard?['leagues'] as List?)?.firstOrNull as Map?;
  for (final logo in (league?['logos'] as List? ?? const []).whereType<Map>()) {
    if ((logo['rel'] as List? ?? const []).contains('default')) return logo['href'] as String?;
  }
  return null;
}

/// Maps one ESPN soccer scoreboard event; null when it can't be read.
Match? parseFootballEvent(Map<String, dynamic> e, FootballCompetition comp, DateTime now, {String? leagueLogo}) {
  final comps = e['competitions'] as List?;
  if (comps == null || comps.isEmpty) return null;
  final c = comps.first as Map<String, dynamic>;
  final competitors = (c['competitors'] as List? ?? const []).cast<Map<String, dynamic>>();
  final home = competitors.where((t) => t['homeAway'] == 'home').firstOrNull;
  final away = competitors.where((t) => t['homeAway'] == 'away').firstOrNull;
  final start = DateTime.tryParse(e['date'] as String? ?? '')?.toLocal();
  if (home == null || away == null || start == null) return null;

  final type = (e['status'] as Map?)?['type'] as Map? ?? const {};
  final state = type['state'] as String? ?? 'pre';
  final shortDetail = (type['shortDetail'] as String? ?? '').trim();
  final status = _statusOf(state);

  // Goal scorers per side, e.g. "Saka 22', Rice 58'".
  final scorers = <String, List<String>>{};
  for (final d in (c['details'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    if (d['scoringPlay'] != true || d['shootout'] == true) continue;
    final teamId = (d['team'] as Map?)?['id']?.toString();
    final athlete = ((d['athletesInvolved'] as List?)?.firstOrNull as Map?)?['displayName'] as String?;
    if (teamId == null || athlete == null) continue;
    final minute = (d['clock'] as Map?)?['displayValue'] as String? ?? '';
    final tag = d['ownGoal'] == true ? ' (OG)' : (d['penaltyKick'] == true ? ' (P)' : '');
    scorers.putIfAbsent(teamId, () => []).add('${athlete.split(' ').last} $minute$tag'.trim());
  }
  String? scorersOf(Map<String, dynamic> t) => scorers[(t['team'] as Map?)?['id']?.toString()]?.join(', ');

  final venue = (c['venue'] as Map?)?['fullName'] as String? ?? '';
  return Match(
    id: 'football-${e['id']}',
    sport: Sport.football,
    league: comp.label,
    leagueTone: comp.tone,
    leagueLogoUrl: leagueLogo,
    venue: venue,
    status: status,
    statusLabel: switch (status) {
      MatchStatus.live => '${shortDetail.isEmpty ? '' : '$shortDetail '}LIVE',
      MatchStatus.upcoming => startsIn(start, now),
      MatchStatus.finished => shortDetail.isEmpty ? 'FT' : shortDetail.toUpperCase(),
    },
    home: _team(home['team'] as Map?),
    away: _team(away['team'] as Map?),
    homeScore: status == MatchStatus.upcoming ? null : int.tryParse('${home['score']}'),
    awayScore: status == MatchStatus.upcoming ? null : int.tryParse('${away['score']}'),
    homeDetail: scorersOf(home),
    awayDetail: scorersOf(away),
    footerNote: switch (status) {
      MatchStatus.live => 'Free Stream • No Sign Up',
      MatchStatus.upcoming => 'Kick-off ${hhmm(start)}',
      MatchStatus.finished => type['description'] as String? ?? 'Full Time',
    },
    startTime: start,
    detailsUrl: _matchPage(e),
  );
}

/// Maps one ESPN cricket score panel event; null when it isn't a match PiqX follows.
RankedMatch? parseCricketEvent(Map<String, dynamic> e, String leagueName, DateTime now) {
  final comps = e['competitions'] as List?;
  if (comps == null || comps.isEmpty) return null;
  final c = comps.first as Map<String, dynamic>;
  final competitors = (c['competitors'] as List? ?? const []).cast<Map<String, dynamic>>().toList()
    ..sort((a, b) => (int.tryParse('${a['order']}') ?? 0).compareTo(int.tryParse('${b['order']}') ?? 0));
  final start = DateTime.tryParse(e['date'] as String? ?? '')?.toLocal();
  if (competitors.length != 2 || start == null) return null;

  final format = (c['class'] as Map?)?['generalClassCard'] as String? ?? '';
  final names = competitors.map((t) => (t['team'] as Map?)?['displayName'] as String? ?? '').toList();
  final String pill;
  final int priority;
  final franchise = leagueName.contains('Women')
      ? null
      : majorCricketLeagues.entries.where((l) => leagueName.contains(l.key)).firstOrNull;
  if (_internationalFormats.contains(format) && names.any(topCricketNations.contains)) {
    pill = format == 'Test' ? 'Test' : format;
    priority = 0;
  } else if (franchise != null) {
    pill = franchise.value;
    priority = 1;
  } else {
    return null;
  }

  final status = e['status'] as Map? ?? const {};
  final type = status['type'] as Map? ?? const {};
  final state = type['state'] as String? ?? 'pre';
  final matchStatus = _statusOf(state);
  final summary = (status['summary'] as String? ?? '').trim();

  bool batting(Map<String, dynamic> t) => (t['linescores'] as List? ?? const [])
      .whereType<Map>()
      .any((l) => l['isBatting'] == true && '${l['isCurrent']}' == '1');
  final homeBatting = matchStatus == MatchStatus.live
      ? (batting(competitors[0]) ? true : (batting(competitors[1]) ? false : null))
      : null;

  String? score(Map<String, dynamic> t) {
    final s = (t['score'] as String? ?? '').trim();
    return s.isEmpty ? null : s;
  }

  final venueParts = [
    (c['description'] as String? ?? '').trim(),
    (((c['venue'] as Map?)?['address'] as Map?)?['city'] as String? ?? '').trim(),
  ].where((s) => s.isNotEmpty);

  return RankedMatch(
    Match(
      id: 'cricket-${e['id']}',
      sport: Sport.cricket,
      league: pill,
      leagueTone: priority == 0 ? LeagueTone.secondary : LeagueTone.neutral,
      venue: venueParts.join(' • '),
      status: matchStatus,
      statusLabel: switch (matchStatus) {
        MatchStatus.live => 'LIVE',
        MatchStatus.upcoming => startsIn(start, now),
        MatchStatus.finished => type['description'] == 'Result' ? 'RESULT' : '${type['description'] ?? 'RESULT'}'.toUpperCase(),
      },
      home: _team(competitors[0]['team'] as Map?),
      away: _team(competitors[1]['team'] as Map?),
      homeDetail: score(competitors[0]),
      awayDetail: score(competitors[1]),
      homeBatting: homeBatting,
      footerNote: summary.isNotEmpty ? summary : 'Starts ${hhmm(start)}',
      startTime: start,
      detailsUrl: _matchPage(e),
    ),
    priority,
  );
}

/// The event's ESPN match page: the link tagged `summary`, or `live` while the match is on.
String? _matchPage(Map<String, dynamic> e) {
  for (final link in (e['links'] as List? ?? const []).whereType<Map>()) {
    final href = link['href'] as String?;
    final rel = link['rel'] as List? ?? const [];
    if (href != null && href.startsWith('https://') && (rel.contains('summary') || rel.contains('live'))) {
      return href;
    }
  }
  return null;
}

MatchStatus _statusOf(String state) => switch (state) {
      'in' => MatchStatus.live,
      'post' => MatchStatus.finished,
      _ => MatchStatus.upcoming,
    };

Team _team(Map? t) {
  final name = t?['displayName'] as String? ?? t?['name'] as String? ?? 'TBD';
  var code = (t?['abbreviation'] as String? ?? '').trim();
  if (code.isEmpty) code = name.replaceAll(' ', '');
  final logo = (t?['logo'] as String? ?? '').trim();
  return Team(
    name,
    code.length > 4 ? code.substring(0, 4).toUpperCase() : code.toUpperCase(),
    logo.isEmpty ? null : logo,
  );
}

/// Countdown label for an upcoming match, e.g. "STARTS IN 1h 15m".
String startsIn(DateTime start, DateTime now) {
  final d = start.difference(now);
  if (d.inMinutes <= 0) return 'STARTING SOON';
  if (d.inHours == 0) return 'STARTS IN ${d.inMinutes}m';
  if (d.inHours < 24) return 'STARTS IN ${d.inHours}h ${d.inMinutes % 60}m';
  return 'STARTS ${hhmm(start)}';
}

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
