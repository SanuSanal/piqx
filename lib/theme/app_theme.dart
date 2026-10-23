import 'package:flutter/material.dart';

/// Colour tokens from the Stitch "PiqX Sports Platform" design system.
@immutable
class PiqxColors extends ThemeExtension<PiqxColors> {
  const PiqxColors({
    required this.surface,
    required this.surfaceBright,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outlineVariant,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.onPrimaryFixed,
    required this.primaryText,
    required this.secondaryContainer,
    required this.secondaryText,
    required this.live,
    required this.onLive,
    required this.error,
    required this.errorContainer,
  });

  final Color surface;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outlineVariant;

  /// Electric green fill used for primary actions and active states.
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color onPrimaryFixed;

  /// Electric green used as a text colour (darkened in light mode for contrast).
  final Color primaryText;

  /// Vibrant cyan fill / accent.
  final Color secondaryContainer;

  /// Vibrant cyan used as a text colour (darkened in light mode for contrast).
  final Color secondaryText;

  /// Signal red, reserved for LIVE states.
  final Color live;
  final Color onLive;
  final Color error;
  final Color errorContainer;

  static const dark = PiqxColors(
    surface: Color(0xFF111318),
    surfaceBright: Color(0xFF37393F),
    surfaceContainerLowest: Color(0xFF0C0E13),
    surfaceContainerLow: Color(0xFF1A1B21),
    surfaceContainer: Color(0xFF1E1F25),
    surfaceContainerHigh: Color(0xFF282A2F),
    surfaceContainerHighest: Color(0xFF33353A),
    onSurface: Color(0xFFE2E2E9),
    onSurfaceVariant: Color(0xFFB9CBBD),
    outlineVariant: Color(0xFF3B4A3F),
    primaryContainer: Color(0xFF00F59B),
    onPrimaryContainer: Color(0xFF006B41),
    onPrimaryFixed: Color(0xFF002111),
    primaryText: Color(0xFF00F59B),
    secondaryContainer: Color(0xFF00D2FF),
    secondaryText: Color(0xFF00D2FF),
    live: Color(0xFFFF3B30),
    onLive: Color(0xFFFFFFFF),
    error: Color(0xFFFFB4AB),
    errorContainer: Color(0xFF93000A),
  );

  static const light = PiqxColors(
    surface: Color(0xFFF4F6F9),
    surfaceBright: Color(0xFFDDE2E9),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFEDF0F4),
    surfaceContainerHigh: Color(0xFFE6EAF0),
    surfaceContainerHighest: Color(0xFFDCE1E8),
    onSurface: Color(0xFF111318),
    onSurfaceVariant: Color(0xFF55606F),
    outlineVariant: Color(0xFFB8C2CF),
    primaryContainer: Color(0xFF00F59B),
    onPrimaryContainer: Color(0xFF006B41),
    onPrimaryFixed: Color(0xFF002111),
    primaryText: Color(0xFF00965E),
    secondaryContainer: Color(0xFF00D2FF),
    secondaryText: Color(0xFF007C99),
    live: Color(0xFFFF3B30),
    onLive: Color(0xFFFFFFFF),
    error: Color(0xFFBA1A1A),
    errorContainer: Color(0xFFFFDAD6),
  );

  @override
  PiqxColors copyWith() => this;

  @override
  PiqxColors lerp(PiqxColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PiqxColors(
      surface: l(surface, other.surface),
      surfaceBright: l(surfaceBright, other.surfaceBright),
      surfaceContainerLowest: l(surfaceContainerLowest, other.surfaceContainerLowest),
      surfaceContainerLow: l(surfaceContainerLow, other.surfaceContainerLow),
      surfaceContainer: l(surfaceContainer, other.surfaceContainer),
      surfaceContainerHigh: l(surfaceContainerHigh, other.surfaceContainerHigh),
      surfaceContainerHighest: l(surfaceContainerHighest, other.surfaceContainerHighest),
      onSurface: l(onSurface, other.onSurface),
      onSurfaceVariant: l(onSurfaceVariant, other.onSurfaceVariant),
      outlineVariant: l(outlineVariant, other.outlineVariant),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      onPrimaryFixed: l(onPrimaryFixed, other.onPrimaryFixed),
      primaryText: l(primaryText, other.primaryText),
      secondaryContainer: l(secondaryContainer, other.secondaryContainer),
      secondaryText: l(secondaryText, other.secondaryText),
      live: l(live, other.live),
      onLive: l(onLive, other.onLive),
      error: l(error, other.error),
      errorContainer: l(errorContainer, other.errorContainer),
    );
  }
}

extension PiqxThemeContext on BuildContext {
  PiqxColors get colors => Theme.of(this).extension<PiqxColors>()!;
}

/// Typography scale from the design system.
abstract final class AppText {
  static const _display = 'Space Grotesk';
  static const _body = 'Plus Jakarta Sans';
  static const mono = 'monospace';

  static const headlineMd = TextStyle(
    fontFamily: _display,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.22,
  );
  static const headlineSm = TextStyle(
    fontFamily: _display,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );
  static const score = TextStyle(
    fontFamily: _display,
    fontSize: 28,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.84,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const labelLg = TextStyle(
    fontFamily: _display,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.52,
  );
  static const labelMd = TextStyle(
    fontFamily: _display,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.66,
  );
  static const labelSm = TextStyle(
    fontFamily: _display,
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
  static const bodyLg = TextStyle(
    fontFamily: _body,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
  );
  static const bodyMd = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
  static const bodySm = TextStyle(
    fontFamily: _body,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? PiqxColors.dark : PiqxColors.light;
  return ThemeData(
    brightness: brightness,
    fontFamily: 'Plus Jakarta Sans',
    scaffoldBackgroundColor: c.surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.primaryContainer,
      brightness: brightness,
      primary: c.primaryContainer,
      secondary: c.secondaryContainer,
      surface: c.surface,
      error: c.error,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surfaceContainerHighest,
      contentTextStyle: AppText.bodyMd.copyWith(color: c.onSurface),
    ),
    extensions: [c],
  );
}
