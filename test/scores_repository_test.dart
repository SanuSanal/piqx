import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:piqx/data/matches.dart';
import 'package:piqx/data/scores_repository.dart';

// Trimmed copies of ESPN's scoreboard / score panel payloads.
Map<String, dynamic> soccerEvent({
  required String id,
  required String date,
  required String state,
  String shortDetail = '',
  String description = '',
  String home = 'Arsenal',
  String away = 'Everton',
  String homeScore = '0',
  String awayScore = '0',
  List<Map<String, dynamic>> details = const [],
}) =>
    {
      'id': id,
      'date': date,
      'links': [
        // ESPN tags the match page `live` while the match is on, `summary` otherwise.
        {
          'rel': [state == 'in' ? 'live' : 'summary', 'desktop', 'event'],
          'href': 'https://www.espn.com/soccer/match/_/gameId/$id/everton-arsenal',
        },
        {
          'rel': ['team-stats', 'desktop', 'event'],
          'href': 'https://www.espn.com/soccer/team-stats/_/gameId/$id/league/eng.1',
        },
      ],
      'status': {
        'type': {'state': state, 'shortDetail': shortDetail, 'description': description},
      },
      'competitions': [
        {
          'venue': {'fullName': 'Emirates Stadium'},
          'competitors': [
            {
              'homeAway': 'home',
              'score': homeScore,
              'team': {
                'id': '1',
                'displayName': home,
                'abbreviation': 'ARS',
                'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/359.png',
              },
            },
            {'homeAway': 'away', 'score': awayScore, 'team': {'id': '2', 'displayName': away, 'abbreviation': 'EVE'}},
          ],
          'details': details,
        },
      ],
    };

Map<String, dynamic> goal(String teamId, String player, String minute, {bool own = false, bool pen = false}) => {
      'scoringPlay': true,
      'ownGoal': own,
      'penaltyKick': pen,
      'shootout': false,
      'clock': {'displayValue': minute},
      'team': {'id': teamId},
      'athletesInvolved': [
        {'displayName': player},
      ],
    };

Map<String, dynamic> cricketEvent({
  required String id,
  required String date,
  required String state,
  required String format,
  required String first,
  required String second,
  String firstScore = '',
  String secondScore = '',
  bool firstBatting = false,
  String summary = '',
  String description = 'Result',
}) =>
    {
      'id': id,
      'date': date,
      'links': [
        {
          'rel': ['event', 'league', 'serieshome', 'desktop'],
          'href': 'https://www.espn.in/cricket/series/_/id/1/season/2026/series',
        },
        {
          'rel': ['event', 'boxscore', 'match', 'live', 'summary', 'desktop'],
          'href': 'https://www.espn.in/cricket/series/1/game/$id/match',
        },
      ],
      'status': {
        'summary': summary,
        'type': {'state': state, 'description': description},
      },
      'competitions': [
        {
          'description': '2nd T20I',
          'class': {'generalClassCard': format},
          'venue': {
            'address': {'city': 'Melbourne'},
          },
          'competitors': [
            {
              'order': 2,
              'score': secondScore,
              'team': {'displayName': second, 'abbreviation': second.substring(0, 3).toUpperCase()},
              'linescores': [
                {'isBatting': !firstBatting && state == 'in', 'isCurrent': 1},
              ],
            },
            {
              'order': 1,
              'score': firstScore,
              'team': {'displayName': first, 'abbreviation': first.substring(0, 3).toUpperCase()},
              'linescores': [
                {'isBatting': firstBatting, 'isCurrent': 1},
              ],
            },
          ],
        },
      ],
    };

void main() {
  // 24 Oct 2026, 15:00 local time.
  final now = DateTime(2026, 10, 24, 15);
  String iso(DateTime local) => local.toUtc().toIso8601String();

  group('parseFootballEvent', () {
    const pl = FootballCompetition('eng.1', 'Premier League', LeagueTone.neutral);

    test('live match with scorers', () {
      final m = parseFootballEvent(
        soccerEvent(
          id: '9',
          date: iso(DateTime(2026, 10, 24, 14)),
          state: 'in',
          shortDetail: "68'",
          homeScore: '2',
          awayScore: '1',
          details: [goal('1', 'Bukayo Saka', "22'"), goal('2', 'Beto', "41'", pen: true), goal('1', 'Declan Rice', "58'")],
        ),
        pl,
        now,
      )!;
      expect(m.id, 'football-9');
      expect(m.status, MatchStatus.live);
      expect(m.statusLabel, "68' LIVE");
      expect((m.homeScore, m.awayScore), (2, 1));
      expect(m.homeDetail, "Saka 22', Rice 58'");
      expect(m.awayDetail, "Beto 41' (P)");
      expect(m.league, 'Premier League');
      expect(m.leagueTone, LeagueTone.neutral);
      expect(m.home.logoUrl, 'https://a.espncdn.com/i/teamlogos/soccer/500/359.png');
      expect(m.away.logoUrl, isNull);
      expect(m.detailsUrl, 'https://www.espn.com/soccer/match/_/gameId/9/everton-arsenal');
    });

    test('upcoming match has a countdown and no score', () {
      final m = parseFootballEvent(
        soccerEvent(id: '1', date: iso(DateTime(2026, 10, 24, 16, 15)), state: 'pre'),
        pl,
        now,
      )!;
      expect(m.status, MatchStatus.upcoming);
      expect(m.statusLabel, 'STARTS IN 1h 15m');
      expect(m.homeScore, isNull);
      expect(m.footerNote, 'Kick-off 16:15');
    });

    test('finished match', () {
      final m = parseFootballEvent(
        soccerEvent(
          id: '2',
          date: iso(DateTime(2026, 10, 24, 12)),
          state: 'post',
          shortDetail: 'FT',
          description: 'Full Time',
          homeScore: '4',
          awayScore: '1',
        ),
        pl,
        now,
      )!;
      expect(m.status, MatchStatus.finished);
      expect(m.statusLabel, 'FT');
      expect(m.footerNote, 'Full Time');
      expect(m.detailsUrl, 'https://www.espn.com/soccer/match/_/gameId/2/everton-arsenal');
    });
  });

  test('league logo is the default one from the scoreboard', () {
    expect(
      leagueLogo({
        'leagues': [
          {
            'logos': [
              {'rel': ['full', 'dark'], 'href': 'https://a.espncdn.com/i/leaguelogos/soccer/500-dark/23.png'},
              {'rel': ['full', 'default'], 'href': 'https://a.espncdn.com/i/leaguelogos/soccer/500/23.png'},
            ],
          },
        ],
      }),
      'https://a.espncdn.com/i/leaguelogos/soccer/500/23.png',
    );
    expect(leagueLogo(null), isNull);
  });

  group('parseCricketEvent', () {
    test('top-ten international is kept, batting side detected, order respected', () {
      final r = parseCricketEvent(
        cricketEvent(
          id: '5',
          date: iso(DateTime(2026, 10, 24, 11)),
          state: 'in',
          format: 'T20I',
          first: 'Australia',
          second: 'India',
          firstScore: '165/8',
          secondScore: '168/4 (17.2/20 ov, target 166)',
          summary: 'India need 18 runs in 16 balls',
        ),
        "India tour of Australia 2026",
        now,
      )!;
      final m = r.match;
      expect(r.priority, 0);
      expect(m.home.name, 'Australia'); // batted first
      expect(m.away.name, 'India');
      expect(m.homeBatting, false);
      expect(m.detailsUrl, 'https://www.espn.in/cricket/series/1/game/5/match');
      expect(m.league, 'T20I');
      expect(m.venue, '2nd T20I • Melbourne');
      expect(m.footerNote, 'India need 18 runs in 16 balls');
      expect(m.awayDetail, '168/4 (17.2/20 ov, target 166)');
    });

    test('IPL is kept with its short label', () {
      final r = parseCricketEvent(
        cricketEvent(
          id: '6',
          date: iso(DateTime(2026, 10, 24, 19, 30)),
          state: 'pre',
          format: 'Twenty20',
          first: 'Mumbai Indians',
          second: 'Chennai Super Kings',
        ),
        'Indian Premier League',
        now,
      )!;
      expect(r.match.league, 'IPL');
      expect(r.priority, 1);
      expect(r.match.statusLabel, 'STARTS IN 4h 30m');
    });

    test('associate internationals, A sides, domestic and women\'s leagues are skipped', () {
      Map<String, dynamic> event(String format, String a, String b) =>
          cricketEvent(id: '7', date: iso(now), state: 'pre', format: format, first: a, second: b);
      expect(parseCricketEvent(event('T20I', 'Nigeria', 'Mozambique'), 'ICC Qualifier', now), isNull);
      expect(parseCricketEvent(event('First-class', 'India A', 'New Zealand A'), 'India A tour', now), isNull);
      expect(parseCricketEvent(event('List A', 'Tasmania', 'Victoria'), 'Australian Domestic One-Day Cup', now), isNull);
      expect(parseCricketEvent(event('Twenty20', 'Sydney Sixers', 'Perth Scorchers'), "Women's Big Bash League", now),
          isNull);
    });
  });

  test('fetchToday merges competitions, keeps today, features the top live match', () async {
    final client = MockClient((req) async {
      final url = req.url.toString();
      Map<String, dynamic> body = {'events': []};
      if (url.contains('/soccer/eng.1/')) {
        body = {
          'events': [
            soccerEvent(id: 'pl-late', date: iso(DateTime(2026, 10, 24, 20)), state: 'pre'),
            soccerEvent(id: 'pl-live', date: iso(DateTime(2026, 10, 24, 14)), state: 'in', shortDetail: "30'"),
            soccerEvent(id: 'pl-tomorrow', date: iso(DateTime(2026, 10, 25, 14)), state: 'pre'),
          ],
        };
      } else if (url.contains('/soccer/uefa.champions/')) {
        body = {
          'events': [soccerEvent(id: 'ucl-live', date: iso(DateTime(2026, 10, 24, 14)), state: 'in', shortDetail: "75'")],
        };
      } else if (url.contains('/cricket/scorepanel')) {
        body = {
          'scores': [
            {
              'leagues': [
                {'name': 'Indian Premier League'},
              ],
              'events': [
                cricketEvent(
                  id: 'ipl',
                  date: iso(DateTime(2026, 10, 24, 19, 30)),
                  state: 'pre',
                  format: 'Twenty20',
                  first: 'Mumbai Indians',
                  second: 'Chennai Super Kings',
                ),
              ],
            },
          ],
        };
      }
      return http.Response(jsonEncode(body), 200);
    });

    final matches = await EspnScoresRepository(client: client, clock: () => now).fetchToday();
    final football = matches.where((m) => m.sport == Sport.football).toList();
    expect(football.map((m) => m.id), ['football-ucl-live', 'football-pl-live', 'football-pl-late']);
    expect(matches.where((m) => m.sport == Sport.cricket).single.league, 'IPL');
  });

  test('fetchToday throws when every request fails', () async {
    final client = MockClient((_) async => http.Response('nope', 503));
    expect(
      EspnScoresRepository(client: client, clock: () => now).fetchToday(),
      throwsA(isA<ScoresUnavailable>()),
    );
  });
}
