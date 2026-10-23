import 'package:flutter/material.dart';

import '../data/matches.dart';
import '../theme/app_theme.dart';
import 'live_badge.dart';

/// Picks the card layout for [match] the way the Stitch home screen does.
class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.onWatch});

  final Match match;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    if (match.featured) {
      return match.sport == Sport.cricket
          ? _FeaturedCricketCard(match: match, onWatch: onWatch)
          : _FeaturedFootballCard(match: match, onWatch: onWatch);
    }
    return _CompactMatchCard(match: match, onWatch: onWatch);
  }
}

class _FeaturedShell extends StatelessWidget {
  const _FeaturedShell({required this.child, required this.glow, this.onTap});

  final Widget child;
  final Color glow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primaryContainer.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                top: -48,
                right: -48,
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [glow.withValues(alpha: 0.14), glow.withValues(alpha: 0)]),
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.all(16), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaguePill extends StatelessWidget {
  const _LeaguePill({required this.match, this.large = false});

  final Match match;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (match.leagueTone) {
      LeagueTone.neutral => c.onSurface,
      LeagueTone.secondary => c.secondaryText,
      LeagueTone.muted => c.onSurfaceVariant,
    };
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(large ? 6 : 4),
      ),
      child: Text(match.league.toUpperCase(), style: AppText.labelSm.copyWith(color: color)),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.match, this.large = false});

  final Match match;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final venueStyle = large ? AppText.labelSm : AppText.bodySm;
    return Row(
      children: [
        _LeaguePill(match: match, large: large),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            match.venue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: venueStyle.copyWith(color: c.onSurfaceVariant, fontWeight: large ? FontWeight.w500 : null),
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

/// Team crest in a rounded tile, or the team code while it loads or when there's no crest.
class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.team, required this.size, this.color, this.bordered = false});

  final Team team;
  final double size;

  /// Colour of the code fallback.
  final Color? color;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = size >= 44 ? AppText.headlineSm : AppText.labelLg;
    final code = Text(
      team.code,
      style: style.copyWith(color: color ?? c.onSurface, fontWeight: FontWeight.w700, letterSpacing: 0),
    );
    final logo = team.logoUrl;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: logo == null ? null : EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(size >= 44 ? 12 : 8),
        border: bordered ? Border.all(color: c.outlineVariant.withValues(alpha: 0.3)) : null,
      ),
      child: logo == null
          ? code
          : _LogoImage(urls: teamLogoUrls(logo, dark: dark, px: px), fallback: code, semanticLabel: team.name),
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

/// Logo URLs to try for an ESPN crest, best first: the dark-background variant in dark mode
/// (football only — ESPN has no dark cricket logos), then the standard one. ESPN images are
/// fetched resized to [px] so cards don't download 500px originals.
List<String> teamLogoUrls(String logo, {required bool dark, required int px}) {
  final uri = Uri.tryParse(logo);
  if (uri == null || uri.host != 'a.espncdn.com' || !uri.path.startsWith('/i/')) return [logo];
  String sized(String path) => 'https://a.espncdn.com/combiner/i?img=$path&w=$px&h=$px';
  final path = uri.path;
  return [
    if (dark && path.contains('/teamlogos/soccer/500/')) sized(path.replaceFirst('/500/', '/500-dark/')),
    sized(path),
  ];
}

class _FeaturedFootballCard extends StatelessWidget {
  const _FeaturedFootballCard({required this.match, required this.onWatch});

  final Match match;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget team(Team t, String? detail, {required bool end}) {
      final names = Column(
        crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppText.headlineSm.copyWith(color: c.onSurface)),
          if (detail != null)
            Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppText.bodySm.copyWith(color: c.onSurfaceVariant)),
        ],
      );
      final code = _TeamBadge(
        team: t,
        size: 44,
        bordered: true,
        color: end ? c.secondaryText : null,
      );
      return Expanded(
        child: Row(
          mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: end
              ? [Flexible(child: names), const SizedBox(width: 12), code]
              : [code, const SizedBox(width: 12), Flexible(child: names)],
        ),
      );
    }

    return _FeaturedShell(
      glow: c.primaryContainer,
      onTap: onWatch,
      child: Column(
        children: [
          _CardHeader(match: match, large: true),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                team(match.home, match.homeDetail, end: false),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Text('${match.homeScore}', style: AppText.score.copyWith(color: c.onSurface)),
                      const SizedBox(width: 8),
                      Text(':', style: AppText.score.copyWith(fontSize: 24, color: c.primaryText)),
                      const SizedBox(width: 8),
                      Text('${match.awayScore}', style: AppText.score.copyWith(color: c.onSurface)),
                    ],
                  ),
                ),
                team(match.away, match.awayDetail, end: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCricketCard extends StatelessWidget {
  const _FeaturedCricketCard({required this.match, required this.onWatch});

  final Match match;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mono = AppText.labelSm.copyWith(fontFamily: AppText.mono);

    // The batting side is drawn in full; the other is dimmed. Before anyone bats, both are full.
    Widget side(Team team, String? detail, {required bool batting, required bool dimmed}) {
      final row = Row(
        children: [
          _TeamBadge(team: team, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: team.name,
                  style: (dimmed ? AppText.bodyLg : AppText.headlineSm).copyWith(color: c.onSurface),
                ),
                if (detail != null) ...[
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: detail,
                    style: dimmed
                        ? mono.copyWith(color: c.onSurfaceVariant, fontWeight: FontWeight.w400)
                        : mono.copyWith(color: c.primaryText),
                  ),
                ],
              ]),
            ),
          ),
          if (batting && match.battingNote != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: c.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(match.battingNote!, style: AppText.labelSm.copyWith(color: c.primaryText)),
            ),
        ],
      );
      return dimmed ? Opacity(opacity: 0.75, child: row) : row;
    }

    final homeBatting = match.homeBatting;
    return _FeaturedShell(
      glow: c.secondaryContainer,
      child: Column(
        children: [
          _CardHeader(match: match, large: true),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                side(match.home, match.homeDetail, batting: homeBatting == true, dimmed: homeBatting == false),
                const SizedBox(height: 8),
                side(match.away, match.awayDetail, batting: homeBatting == false, dimmed: homeBatting == true),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
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
                const SizedBox(width: 12),
                _PrimaryWatchButton(onPressed: onWatch),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryWatchButton extends StatelessWidget {
  const _PrimaryWatchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: c.primaryContainer.withValues(alpha: 0.4), blurRadius: 16)],
      ),
      child: Material(
        color: c.primaryContainer,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 18, color: c.onPrimaryFixed),
                  const SizedBox(width: 6),
                  Text(
                    'Watch Live',
                    style: AppText.headlineSm.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: c.onPrimaryFixed),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactMatchCard extends StatelessWidget {
  const _CompactMatchCard({required this.match, required this.onWatch});

  final Match match;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Cricket shows each side's innings under its name, e.g. "168/4 (17.2 ov)".
    Widget name(Team t, String? detail, {required bool end}) {
      final showDetail = match.sport == Sport.cricket && detail != null;
      return Expanded(
        child: Row(
          mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!end) ...[_TeamBadge(team: t, size: 36), const SizedBox(width: 10)],
            Flexible(
              child: Column(
                crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      textAlign: end ? TextAlign.right : TextAlign.left,
                      style: AppText.headlineSm.copyWith(color: c.onSurface)),
                  if (showDetail)
                    Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis,
                        textAlign: end ? TextAlign.right : TextAlign.left,
                        style: AppText.labelSm.copyWith(
                          fontFamily: AppText.mono,
                          fontWeight: FontWeight.w400,
                          color: c.onSurfaceVariant,
                        )),
                ],
              ),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          _CardHeader(match: match),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              name(match.home, match.homeDetail, end: false),
              centre,
              name(match.away, match.awayDetail, end: true),
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
