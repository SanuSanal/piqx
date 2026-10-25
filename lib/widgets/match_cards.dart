import 'package:flutter/material.dart';

import '../data/matches.dart';
import '../theme/app_theme.dart';
import 'live_badge.dart';

/// Picks the card layout for [match] the way the Stitch home screen does.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.onOpen, required this.onWatch});

  final Match match;

  /// Tapping the card: the match's ESPN page, or its stream when it has no page.
  final VoidCallback onOpen;

  /// The Watch Live button on compact football cards: always the stream.
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    if (match.sport == Sport.cricket) return _CricketCard(match: match, onOpen: onOpen);
    return _CompactMatchCard(match: match, onOpen: onOpen, onWatch: onWatch);
  }
}

/// Competitions on today's slate as chips above the match list: tapping one shows only its
/// matches, tapping it again shows everything.
class LeagueFilterBar extends StatelessWidget {
  const LeagueFilterBar({super.key, required this.leagues, required this.selected, required this.onSelect});

  /// Competition names with their logos, in display order.
  final List<(String, String?)> leagues;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: leagues.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (name, logo) = leagues[i];
          final active = name == selected;
          return _LeagueChip(name: name, logo: logo, active: active, onTap: () => onSelect(active ? null : name));
        },
      ),
    );
  }
}

class _LeagueChip extends StatelessWidget {
  const _LeagueChip({required this.name, required this.logo, required this.active, required this.onTap});

  final String name;
  final String? logo;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const logoSize = 24.0;
    final px = (logoSize * MediaQuery.devicePixelRatioOf(context)).round();
    final shape = StadiumBorder(
      side: BorderSide(color: active ? c.primaryContainer : c.outlineVariant.withValues(alpha: 0.3)),
    );
    return Material(
      color: active ? c.primaryContainer.withValues(alpha: 0.15) : c.surfaceContainerHigh,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: EdgeInsets.only(left: logo == null ? 14 : 8, right: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logo != null) ...[
                SizedBox.square(
                  dimension: logoSize,
                  child: _LogoImage(
                    urls: espnLogoUrls(logo!, dark: dark, px: px),
                    fallback: const SizedBox.shrink(),
                    semanticLabel: name,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(name,
                  style: AppText.labelLg.copyWith(
                    color: active ? c.primaryText : c.onSurface,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable shell of the smaller cards.
class _CompactShell extends StatelessWidget {
  const _CompactShell({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: child)),
    );
  }
}

class _LeaguePill extends StatelessWidget {
  const _LeaguePill({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (match.leagueTone) {
      LeagueTone.neutral => c.onSurface,
      LeagueTone.secondary => c.secondaryText,
      LeagueTone.muted => c.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(match.league.toUpperCase(), style: AppText.labelSm.copyWith(color: color)),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        _LeaguePill(match: match),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            match.venue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        switch (match.status) {
          MatchStatus.live => LiveBadge(label: match.statusLabel),
          MatchStatus.upcoming => _UpcomingBadge(label: match.statusLabel),
          MatchStatus.finished => _FinishedBadge(label: match.statusLabel),
        },
      ],
    );
  }
}

class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 13, color: c.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: AppText.labelSm.copyWith(color: c.onSurfaceVariant, fontFamily: AppText.mono)),
        ],
      ),
    );
  }
}

class _UpcomingBadge extends StatelessWidget {
  const _UpcomingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 13, color: c.secondaryText),
          const SizedBox(width: 4),
          Text(label, style: AppText.labelSm.copyWith(color: c.secondaryText, fontFamily: AppText.mono)),
        ],
      ),
    );
  }
}

/// Team crest filling its square, or the team code (in a rounded tile when there's no crest).
class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.team, required this.size});

  final Team team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final code = Text(
      team.code,
      style: AppText.labelLg.copyWith(color: c.onSurface, fontWeight: FontWeight.w700, letterSpacing: 0),
    );
    final logo = team.logoUrl;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    if (logo != null) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: _LogoImage(urls: espnLogoUrls(logo, dark: dark, px: px), fallback: code, semanticLabel: team.name),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: code,
    );
  }
}

/// Tries [urls] in order and shows [fallback] while loading or once every URL has failed.
class _LogoImage extends StatelessWidget {
  const _LogoImage({required this.urls, required this.fallback, required this.semanticLabel});

  final List<String> urls;
  final Widget fallback;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return fallback;
    return Image.network(
      urls.first,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      frameBuilder: (context, child, frame, sync) => frame == null && !sync ? fallback : child,
      errorBuilder: (context, error, stack) =>
          _LogoImage(urls: urls.sublist(1), fallback: fallback, semanticLabel: semanticLabel),
    );
  }
}

/// Logo URLs to try for an ESPN crest or league logo, best first: the dark-background variant
/// in dark mode (football only — ESPN has no dark cricket logos), then the standard one. ESPN
/// images are fetched resized to [px] so cards don't download 500px originals.
List<String> espnLogoUrls(String logo, {required bool dark, required int px}) {
  final uri = Uri.tryParse(logo);
  if (uri == null || uri.host != 'a.espncdn.com' || !uri.path.startsWith('/i/')) return [logo];
  String sized(String path) => 'https://a.espncdn.com/combiner/i?img=$path&w=$px&h=$px';
  final path = uri.path;
  return [
    if (dark && path.contains('/soccer/500/')) sized(path.replaceFirst('/500/', '/500-dark/')),
    sized(path),
  ];
}

/// Cricket card: one row per side with its innings on the right and a bat by the side batting.
/// The whole card opens the match; there's no watch button.
class _CricketCard extends StatelessWidget {
  const _CricketCard({required this.match, required this.onOpen});

  final Match match;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // The batting side is drawn in full; the other is dimmed. Before anyone bats, both are full.
    Widget side(Team team, String? detail, {required bool batting, required bool dimmed}) {
      final (runs, overs) = splitInnings(detail);
      final row = Row(
        children: [
          _TeamBadge(team: team, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(team.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: (dimmed ? AppText.bodyLg : AppText.headlineSm).copyWith(color: c.onSurface)),
                ),
                if (batting) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.sports_cricket, size: 18, color: c.primaryText, semanticLabel: 'Batting'),
                ],
              ],
            ),
          ),
          if (runs != null) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(runs,
                    style: AppText.headlineSm.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: batting ? c.primaryText : c.onSurface,
                    )),
                if (overs != null)
                  Text(overs,
                      style: AppText.labelLg.copyWith(
                        fontFamily: AppText.mono,
                        fontWeight: FontWeight.w400,
                        color: c.onSurfaceVariant,
                      )),
              ],
            ),
          ],
        ],
      );
      return dimmed ? Opacity(opacity: 0.75, child: row) : row;
    }

    final homeBatting = match.homeBatting;
    final body = Column(
      children: [
        _CardHeader(match: match),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              side(match.home, match.homeDetail, batting: homeBatting == true, dimmed: homeBatting == false),
              const SizedBox(height: 10),
              side(match.away, match.awayDetail, batting: homeBatting == false, dimmed: homeBatting == true),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Icon(Icons.sports_cricket, size: 15, color: c.secondaryText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(match.footerNote,
                    style: AppText.labelSm.copyWith(color: c.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ),
              if (match.status == MatchStatus.upcoming) ...[
                const SizedBox(width: 8),
                const _ReminderButton(),
              ],
            ],
          ),
        ),
      ],
    );

    return _CompactShell(onTap: onOpen, child: body);
  }
}

/// Splits an ESPN innings score into runs and the bracketed overs part:
/// "168/4 (17.2/20 ov, target 166)" → ("168/4", "17.2/20 ov, target 166").
(String?, String?) splitInnings(String? detail) {
  final d = detail?.trim() ?? '';
  if (d.isEmpty) return (null, null);
  final m = RegExp(r'^(.*?)\s*\((.*)\)$').firstMatch(d);
  if (m == null || m.group(1)!.isEmpty) return (d, null);
  return (m.group(1)!, m.group(2)!);
}

class _CompactMatchCard extends StatelessWidget {
  const _CompactMatchCard({required this.match, required this.onOpen, required this.onWatch});

  final Match match;
  final VoidCallback onOpen;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget name(Team t, {required bool end}) {
      return Expanded(
        child: Row(
          mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!end) ...[_TeamBadge(team: t, size: 36), const SizedBox(width: 10)],
            Flexible(
              child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: end ? TextAlign.right : TextAlign.left,
                  style: AppText.headlineSm.copyWith(color: c.onSurface)),
            ),
            if (end) ...[const SizedBox(width: 10), _TeamBadge(team: t, size: 36)],
          ],
        ),
      );
    }

    final Widget centre;
    if (match.homeScore != null && match.awayScore != null) {
      final h = match.homeScore!, a = match.awayScore!;
      final score = AppText.headlineSm.copyWith(fontWeight: FontWeight.w700);
      centre = Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Text('$h', style: score.copyWith(color: h > a ? c.primaryText : c.onSurface)),
            const SizedBox(width: 6),
            Text('-', style: score.copyWith(color: c.primaryText)),
            const SizedBox(width: 6),
            Text('$a', style: score.copyWith(color: a > h ? c.primaryText : c.onSurface)),
          ],
        ),
      );
    } else {
      centre = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('VS', style: AppText.labelLg.copyWith(color: c.onSurfaceVariant)),
      );
    }

    return _CompactShell(
      onTap: onOpen,
      child: Column(
        children: [
          _CardHeader(match: match),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              name(match.home, end: false),
              centre,
              name(match.away, end: true),
            ]),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(match.footerNote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSm.copyWith(color: c.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ),
                if (!match.isFinished) ...[
                  const SizedBox(width: 8),
                  match.isLive ? _SecondaryButton.watch(onPressed: onWatch) : const _ReminderButton(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  const _SecondaryButton.watch({required VoidCallback onPressed})
      : this(icon: Icons.play_circle_outline, label: 'Watch Live', onPressed: onPressed);

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.onPrimaryContainer : c.onSurface;
    return Material(
      color: active ? c.primaryContainer : c.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(label, style: AppText.labelMd.copyWith(color: fg, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderButton extends StatefulWidget {
  const _ReminderButton();

  @override
  State<_ReminderButton> createState() => _ReminderButtonState();
}

class _ReminderButtonState extends State<_ReminderButton> {
  bool _set = false;

  @override
  Widget build(BuildContext context) {
    return _SecondaryButton(
      icon: _set ? Icons.check_circle : Icons.notifications_active_outlined,
      label: _set ? 'Reminder Set' : 'Set Reminder',
      active: _set,
      onPressed: () => setState(() => _set = !_set),
    );
  }
}
