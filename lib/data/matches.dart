enum Sport {
  football('Football', '⚽'),
  cricket('Cricket', '🏏');

  const Sport(this.label, this.emoji);

  final String label;
  final String emoji;
}

enum MatchStatus { live, upcoming, finished }

/// Colour treatment of the competition pill on a match card.
enum LeagueTone { neutral, secondary, muted }

class Team {
  const Team(this.name, this.code);

  final String name;
  final String code;
}

class Match {
  const Match({
    required this.id,
    required this.sport,
    required this.league,
    required this.venue,
    required this.status,
    required this.statusLabel,
    required this.home,
    required this.away,
    required this.footerNote,
    this.leagueTone = LeagueTone.muted,
    this.featured = false,
    this.homeScore,
    this.awayScore,
    this.homeDetail,
    this.awayDetail,
    this.battingNote,
    this.homeBatting,
    this.startTime,
  });

  final String id;
  final Sport sport;
  final String league;
  final LeagueTone leagueTone;
  final String venue;
  final MatchStatus status;

  /// Text in the status badge, e.g. "68' LIVE" or "STARTS IN 1h 15m".
  final String statusLabel;
  final Team home;
  final Team away;

  /// Football: goals. Cricket: unused (see [homeDetail]).
  final int? homeScore;
  final int? awayScore;

  /// Football: goal scorers. Cricket: innings score, e.g. "168/4 (17.2 ov)".
  final String? homeDetail;
  final String? awayDetail;

  /// Cricket only: state of the batting side, e.g. "Batting • Req. 8.2 rpo".
  final String? battingNote;

  /// Cricket only: true when the home side is batting, false when the away side is,
  /// null when nobody is (before the start, between innings, after the result).
  final bool? homeBatting;

  /// Scheduled start, when the feed provides one.
  final DateTime? startTime;

  /// Caption under the teams, e.g. "Free Stream • No Sign Up".
  final String footerNote;

  /// Featured matches get the large marquee card.
  final bool featured;

  bool get isLive => status == MatchStatus.live;
  bool get isFinished => status == MatchStatus.finished;

  Match copyWith({bool? featured}) => Match(
        id: id,
        sport: sport,
        league: league,
        leagueTone: leagueTone,
        venue: venue,
        status: status,
        statusLabel: statusLabel,
        home: home,
        away: away,
        footerNote: footerNote,
        featured: featured ?? this.featured,
        homeScore: homeScore,
        awayScore: awayScore,
        homeDetail: homeDetail,
        awayDetail: awayDetail,
        battingNote: battingNote,
        homeBatting: homeBatting,
        startTime: startTime,
      );
}

/// Public PiqX landing page (GitHub Pages, served from `docs/`).
const appPageUrl = 'https://sanusanal.github.io/piqx/';

/// Web stream page loaded in the stream screen's WebView, per sport.
/// While a sport has no URL, the screen shows the "WebView Viewport" placeholder.
const streamUrls = <Sport, String?>{
  Sport.football: null,
  Sport.cricket: null,
};

/// GitHub repository that publishes PiqX releases (APK assets on version tags).
const githubRepo = 'SanuSanal/piqx';
