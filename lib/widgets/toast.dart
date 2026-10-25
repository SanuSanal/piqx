import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// What a toast is about; sets its icon and accent colour.
enum ToastKind { info, success, error }

/// Shows [message] as a short floating toast above the bottom of the screen, replacing any
/// toast already showing.
///
/// Before an `await`, keep `ScaffoldMessenger.of(context)` and call [ToastMessenger.showToast]
/// on it afterwards instead, so the toast still shows if [context] has gone away.
void showToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
  Duration duration = const Duration(seconds: 3),
}) =>
    ScaffoldMessenger.of(context).showToast(message, kind: kind, duration: duration);

extension ToastMessenger on ScaffoldMessengerState {
  void showToast(String message, {ToastKind kind = ToastKind.info, Duration duration = const Duration(seconds: 3)}) {
    hideCurrentSnackBar();
    showSnackBar(_toast(context, message, kind, duration));
  }

  void hideToast() => hideCurrentSnackBar();
}

SnackBar _toast(BuildContext context, String message, ToastKind kind, Duration duration) {
  final c = context.colors;
  final (icon, accent) = switch (kind) {
    ToastKind.info => (Icons.info_outline_rounded, c.secondaryText),
    ToastKind.success => (Icons.check_circle_outline_rounded, c.primaryText),
    ToastKind.error => (Icons.error_outline_rounded, c.error),
  };
  return SnackBar(
    duration: duration,
    behavior: SnackBarBehavior.floating,
    backgroundColor: c.surfaceContainerHighest,
    elevation: 6,
    margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: accent.withValues(alpha: 0.35)),
    ),
    content: Row(
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: AppText.bodyMd.copyWith(color: c.onSurface))),
      ],
    ),
  );
}
