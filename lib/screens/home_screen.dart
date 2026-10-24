import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/matches.dart';
import '../data/scores_controller.dart';
import '../data/scores_repository.dart';
import '../data/stream_links.dart';
import '../theme/app_theme.dart';
import '../update/update_prompt.dart';
import '../update/update_service.dart';
import '../widgets/live_badge.dart';
import '../widgets/match_cards.dart';
import 'match_details_screen.dart';
import 'stream_screen.dart';

/// "Home - Sports & Today's Matches" from Stitch.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.scores,
    required this.updates,
    required this.streams,
    this.checkUpdatesOnStart = true,
  });

  final VoidCallback onToggleTheme;
  final ScoresController scores;
  final UpdateService updates;
  final StreamLinks streams;
  final bool checkUpdatesOnStart;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Sport _sport = Sport.football;

  /// Competition the match list is filtered to, or null for all of them.
  String? _league;

  @override
  void initState() {
    super.initState();
    if (widget.checkUpdatesOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckForUpdates());
    }
  }

  Future<void> _autoCheckForUpdates() async {
    final enabled = await widget.updates.autoCheckEnabled().catchError((_) => false);
    if (enabled && mounted) await checkForUpdates(context, widget.updates, manual: false);
  }

  void _select(Sport sport) => setState(() {
        _sport = sport;
        _league = null;
      });

  /// Competitions in [matches] with their logos: football in [footballCompetitions] order,
  /// cricket in the order the list shows them.
  static List<(String, String?)> _leaguesOf(List<Match> matches) {
    final logos = <String, String?>{};
    for (final m in matches) {
      logos.putIfAbsent(m.league, () => m.leagueLogoUrl);
    }
    final firstSeen = {for (final (i, name) in logos.keys.indexed) name: i};
    int rank(String name) {
      final i = footballCompetitions.indexWhere((c) => c.label == name);
      return i < 0 ? footballCompetitions.length : i;
    }

    return (logos.keys.toList()
          ..sort((a, b) {
            final r = rank(a).compareTo(rank(b));
            return r != 0 ? r : firstSeen[a]!.compareTo(firstSeen[b]!);
          }))
        .map((name) => (name, logos[name]))
        .toList();
  }

  static const _exitWindow = Duration(seconds: 2);
  DateTime? _lastBack;

  /// Back (button or edge swipe) on home: the first press warns, a second within
  /// [_exitWindow] closes the app.
  void _onBack(bool didPop, Object? _) {
    if (didPop) return;
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < _exitWindow) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Press back again to exit'), duration: _exitWindow));
  }

  /// A match with an ESPN page opens it; otherwise its sport's stream.
  void _open(Match match) {
    final url = match.detailsUrl;
    if (url == null) return _watch(match);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MatchDetailsScreen(match: match, url: url)),
    );
  }

  void _watch(Match match) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StreamScreen(sport: match.sport, match: match, url: widget.streams[match.sport])),
    );
  }

  void _openSport(Sport sport) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StreamScreen(sport: sport, url: widget.streams[sport])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: c.surface,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: _onBack,
        child: Scaffold(
          backgroundColor: c.surface,
          body: Stack(
            children: [
              ListenableBuilder(
                listenable: widget.scores,
                builder: (context, _) {
                  final scores = widget.scores;
                  final all = scores.forSport(_sport);
                  final leagues = _leaguesOf(all);
                  // A competition that dropped off the slate on refresh stops filtering.
                  final league = leagues.any((l) => l.$1 == _league) ? _league : null;
                  final matches = league == null ? all : all.where((m) => m.league == league).toList();
                  return RefreshIndicator(
                    onRefresh: scores.refresh,
                    color: c.onPrimaryFixed,
                    backgroundColor: c.primaryContainer,
                    edgeOffset: topInset + 64,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, topInset + 64 + 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        _ExploreSports(selected: _sport, onOpen: _openSport, scores: scores),
                        const SizedBox(height: 24),
                        _MatchesHeader(selected: _sport, onSelect: _select),
                        const SizedBox(height: 14),
                        if (leagues.length > 1) ...[
                          LeagueFilterBar(
                            leagues: leagues,
                            selected: league,
                            onSelect: (l) => setState(() => _league = l),
                          ),
                          const SizedBox(height: 14),
                        ],
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Column(
                            key: ValueKey((_sport, league, scores.hasLoaded, matches.isEmpty)),
                            children: [
                              if (matches.isEmpty)
                                _MatchesPlaceholder(sport: _sport, scores: scores)
                              else
                                for (final (i, m) in matches.indexed) ...[
                                  if (i > 0) const SizedBox(height: 12),
                                  MatchCard(match: m, onOpen: () => _open(m), onWatch: () => _watch(m)),
                                ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const _Footer(),
                      ],
                    ),
                  );
                },
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _Header(
                  onToggleTheme: widget.onToggleTheme,
                  onOpenUpdates: () => showUpdateSettings(context, widget.updates),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onToggleTheme, required this.onOpenUpdates});

  final VoidCallback onToggleTheme;
  final VoidCallback onOpenUpdates;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.9),
            border: Border(bottom: BorderSide(color: c.outlineVariant.withValues(alpha: 0.3))),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // The wordmark already ends in the Match point X, so it stands alone here.
                    Image.asset(
                      dark ? 'assets/images/logo.png' : 'assets/images/logo_on_light.png',
                      height: 24,
                      semanticLabel: 'PiqX',
                    ),
                    const Spacer(),
                    _HeaderButton(
                      tooltip: 'App updates',
                      icon: Icons.system_update_alt_rounded,
                      onTap: onOpenUpdates,
                    ),
                    const SizedBox(width: 8),
                    _HeaderButton(
                      tooltip: dark ? 'Switch to light theme' : 'Switch to dark theme',
                      icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      onTap: onToggleTheme,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.tooltip, required this.icon, required this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: c.onSurface)),
        ),
      ),
    );
  }
}

class _ExploreSports extends StatelessWidget {
  const _ExploreSports({required this.selected, required this.onOpen, required this.scores});

  /// Highlighted card; follows the Today's Matches tab.
  final Sport selected;
  final ValueChanged<Sport> onOpen;
  final ScoresController scores;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Explore Sports', style: AppText.headlineSm.copyWith(color: c.onSurface)),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
            ),
            const Spacer(),
            Text("TODAY'S SLATE", style: AppText.labelSm.copyWith(color: c.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final sport in Sport.values) ...[
              if (sport.index > 0) const SizedBox(width: 10),
              Expanded(
                child: _SportCard(
                  sport: sport,
                  active: sport == selected,
                  count: scores.hasLoaded ? scores.forSport(sport).length : null,
                  onTap: () => onOpen(sport),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SportCard extends StatelessWidget {
  const _SportCard({required this.sport, required this.active, required this.count, required this.onTap});

  final Sport sport;
  final bool active;

  /// Matches today; null until the first load finishes.
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final countColor = sport == Sport.football ? c.primaryText : c.secondaryText;
    final radius = BorderRadius.circular(16);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: active ? null : c.surfaceContainerLow,
        gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(c.primaryContainer.withValues(alpha: 0.2), c.surfaceContainerHigh),
                  c.surfaceContainerHigh,
                ],
              )
            : null,
        border: active
            ? Border.all(color: c.primaryContainer, width: 2)
            : Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: active
            ? [BoxShadow(color: c.primaryContainer.withValues(alpha: 0.15), blurRadius: 20)]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // Inactive cards have a 1px border instead of 2px; keep content aligned.
            padding: EdgeInsets.all(active ? 12 : 13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? c.primaryContainer.withValues(alpha: 0.2) : c.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(sport.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sport.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.headlineSm.copyWith(color: c.onSurface, height: 1.25)),
                      Text(count == null ? '— TODAY' : '$count TODAY', style: AppText.labelSm.copyWith(color: countColor)),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: active ? 1 : 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: c.primaryContainer, blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchesHeader extends StatelessWidget {
  const _MatchesHeader({required this.selected, required this.onSelect});

  final Sport selected;
  final ValueChanged<Sport> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 20, color: c.primaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text("Today's Matches",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.headlineSm.copyWith(color: c.onSurface)),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: c.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                for (final sport in Sport.values) _TabPill(sport: sport, active: sport == selected, onTap: () => onSelect(sport)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.sport, required this.active, required this.onTap});

  final Sport sport;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? c.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Text(sport.emoji, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 6),
            Text(
              sport.label,
              style: AppText.labelSm.copyWith(color: active ? c.onPrimaryContainer : c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for the match list while loading, after an error, or on a quiet day.
class _MatchesPlaceholder extends StatelessWidget {
  const _MatchesPlaceholder({required this.sport, required this.scores});

  final Sport sport;
  final ScoresController scores;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final loading = !scores.hasLoaded && scores.error == null;
    final failed = !scores.hasLoaded && scores.error != null;
    final (IconData icon, String title, String body) = failed
        ? (Icons.cloud_off_rounded, "Couldn't load scores", 'Check your connection, then pull down or tap Retry.')
        : (
            sport == Sport.football ? Icons.sports_soccer : Icons.sports_cricket,
            'No ${sport.label.toLowerCase()} today',
            sport == Sport.football
                ? 'Nothing on today in the top five leagues, the Champions League, Europa League or Copa del Rey.'
                : 'No matches today for the top ten Test nations, the IPL or the other major leagues.',
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: loading
          ? Column(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3, color: c.primaryContainer),
                ),
                const SizedBox(height: 14),
                Text('Loading live scores…', style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant)),
              ],
            )
          : Column(
              children: [
                Icon(icon, size: 32, color: failed ? c.onSurfaceVariant : c.primaryText),
                const SizedBox(height: 12),
                Text(title, style: AppText.headlineSm.copyWith(color: c.onSurface)),
                const SizedBox(height: 6),
                Text(body, textAlign: TextAlign.center, style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant)),
                if (failed) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: scores.refresh,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.onSurface,
                      side: BorderSide(color: c.outlineVariant),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('Retry', style: AppText.labelLg.copyWith(color: c.onSurface)),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Credit for the scores feed: a small pill with a live dot and the ESPN wordmark.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
          decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulsingDot(color: c.primaryContainer, size: 7),
              const SizedBox(width: 10),
              Text('LIVE SCORES BY',
                  style: AppText.labelSm.copyWith(color: c.onSurfaceVariant, letterSpacing: 1.2)),
              const SizedBox(width: 8),
              Text('ESPN',
                  style: AppText.headlineSm.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.4,
                    height: 1,
                    color: _espnRed,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  static const _espnRed = Color(0xFFE4002B);
}
