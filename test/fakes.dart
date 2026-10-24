import 'package:piqx/data/matches.dart';
import 'package:piqx/data/scores_repository.dart';

/// Serves a fixed slate instead of calling ESPN.
class FakeScoresRepository implements ScoresRepository {
  FakeScoresRepository([this.matches = sampleMatches]);

  final List<Match> matches;

  @override
  Future<List<Match>> fetchToday() async => matches;
}

const sampleMatches = <Match>[
  Match(
    id: 'ars-mci',
    sport: Sport.football,
    league: 'Premier League',
    leagueTone: LeagueTone.neutral,
    venue: 'Emirates Stadium',
    status: MatchStatus.live,
    statusLabel: "68' LIVE",
    home: Team('Arsenal', 'ARS'),
    away: Team('Man City', 'MCI'),
    homeScore: 2,
    awayScore: 1,
    homeDetail: "Saka 22', Rice 58'",
    awayDetail: "Haaland 41'",
    footerNote: 'Free Stream • No Sign Up',
    featured: true,
  ),
  Match(
    id: 'rma-bay',
    sport: Sport.football,
    league: 'Champions League',
    leagueTone: LeagueTone.secondary,
    venue: 'Bernabéu',
    status: MatchStatus.live,
    statusLabel: "82' LIVE",
    home: Team('Real Madrid', 'RMA'),
    away: Team('Bayern Munich', 'BAY'),
    homeScore: 1,
    awayScore: 2,
    footerNote: 'Free Stream • No Sign Up',
  ),
  Match(
    id: 'fcb-atm',
    sport: Sport.football,
    league: 'La Liga',
    venue: '19:45 GMT',
    status: MatchStatus.upcoming,
    statusLabel: 'STARTS IN 1h 15m',
    home: Team('Barcelona', 'FCB'),
    away: Team('Atlético Madrid', 'ATM'),
    footerNote: 'Camp Nou • 4K Stream ready',
  ),
  Match(
    id: 'ind-aus',
    sport: Sport.cricket,
    league: 'T20 International',
    leagueTone: LeagueTone.secondary,
    venue: '2nd T20I • Melbourne',
    status: MatchStatus.live,
    statusLabel: 'LIVE BALL-BY-BALL',
    home: Team('India', 'IND'),
    away: Team('Australia', 'AUS'),
    homeDetail: '168/4 (17.2 ov)',
    awayDetail: '165/8 (20.0 ov)',
    homeBatting: true,
    footerNote: 'India need 18 runs in 16 balls',
    featured: true,
  ),
  Match(
    id: 'eng-rsa',
    sport: Sport.cricket,
    league: 'ODI Series',
    venue: 'Starts 14:30 GMT',
    status: MatchStatus.upcoming,
    statusLabel: 'UPCOMING TODAY',
    home: Team('England', 'ENG'),
    away: Team('South Africa', 'RSA'),
    footerNote: "Lord's, London • Pitch Coverage",
  ),
];
