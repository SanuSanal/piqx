import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'update_service.dart';

/// Checks GitHub for a newer PiqX and offers to install it.
///
/// Automatic checks ([manual] false) stay silent when up to date, offline, or when the
/// user already chose "Later" for that version. Manual checks always report back.
Future<void> checkForUpdates(BuildContext context, UpdateService service, {required bool manual}) async {
  final messenger = ScaffoldMessenger.of(context);
  AppRelease? update;
  try {
    update = await service.availableUpdate();
    if (!manual && update != null && await service.skippedVersion() == update.version) return;
  } catch (_) {
    if (manual) messenger.showSnackBar(const SnackBar(content: Text("Couldn't check for updates. Try again later.")));
    return;
  }
  if (!context.mounted) return;
  if (update == null) {
    if (manual) {
      final current = await service.currentVersion().catchError((_) => '');
      messenger.showSnackBar(SnackBar(content: Text("You're on the latest version${current.isEmpty ? '' : ' (v$current)'}.")));
    }
    return;
  }

  final release = update;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => _UpdateDialog(release: release),
  );
  if (!context.mounted) return;
  if (accepted != true) {
    await service.skip(release.version);
    return;
  }
  await _downloadAndInstall(context, service, release);
}

Future<void> _downloadAndInstall(BuildContext context, UpdateService service, AppRelease release) async {
  final messenger = ScaffoldMessenger.of(context);
  final progress = ValueNotifier<double?>(null);
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _DownloadDialog(version: release.version, progress: progress),
  );
  try {
    final apk = await service.download(release, onProgress: (p) => progress.value = p);
    navigator.pop();
    await service.install(apk);
  } catch (_) {
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('The update failed to download. Check your connection and try again.')));
  } finally {
    progress.dispose();
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.release});

  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.surfaceContainer,
      title: Text('PiqX v${release.version} is available', style: AppText.headlineSm.copyWith(color: c.onSurface)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: SingleChildScrollView(
          child: Text(
            release.notes.isEmpty ? 'A new version of PiqX is ready to install.' : release.notes,
            style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Later', style: AppText.labelLg.copyWith(color: c.onSurfaceVariant)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.primaryContainer, foregroundColor: c.onPrimaryFixed),
          onPressed: () => Navigator.pop(context, true),
          child: Text('Update', style: AppText.labelLg.copyWith(color: c.onPrimaryFixed)),
        ),
      ],
    );
  }
}

class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({required this.version, required this.progress});

  final String version;
  final ValueNotifier<double?> progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: c.surfaceContainer,
        title: Text('Downloading v$version', style: AppText.headlineSm.copyWith(color: c.onSurface)),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  color: c.primaryContainer,
                  backgroundColor: c.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value == null ? 'Starting…' : '${(value * 100).round()}%',
                style: AppText.labelMd.copyWith(color: c.onSurfaceVariant, fontFamily: AppText.mono),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// About & updates sheet: version, the auto-check option, and a manual check.
Future<void> showUpdateSettings(BuildContext context, UpdateService service) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surfaceContainer,
    showDragHandle: true,
    builder: (_) => _UpdateSettingsSheet(service: service, hostContext: context),
  );
}

class _UpdateSettingsSheet extends StatefulWidget {
  const _UpdateSettingsSheet({required this.service, required this.hostContext});

  final UpdateService service;

  /// The screen's context, used for the update dialogs after the sheet closes.
  final BuildContext hostContext;

  @override
  State<_UpdateSettingsSheet> createState() => _UpdateSettingsSheetState();
}

class _UpdateSettingsSheetState extends State<_UpdateSettingsSheet> {
  String? _version;
  bool? _autoCheck;

  @override
  void initState() {
    super.initState();
    widget.service.currentVersion().then((v) => mounted ? setState(() => _version = v) : null, onError: (_) {});
    widget.service.autoCheckEnabled().then((v) => mounted ? setState(() => _autoCheck = v) : null,
        onError: (_) => mounted ? setState(() => _autoCheck = true) : null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App updates', style: AppText.headlineSm.copyWith(color: c.onSurface)),
            const SizedBox(height: 4),
            Text(
              _version == null ? 'PiqX' : 'PiqX v$_version',
              style: AppText.bodySm.copyWith(color: c.onSurfaceVariant, fontFamily: AppText.mono),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoCheck ?? true,
              activeThumbColor: c.onPrimaryFixed,
              activeTrackColor: c.primaryContainer,
              onChanged: _autoCheck == null
                  ? null
                  : (v) {
                      setState(() => _autoCheck = v);
                      widget.service.setAutoCheck(v);
                    },
              title: Text('Check for updates automatically', style: AppText.bodyLg.copyWith(color: c.onSurface)),
              subtitle: Text('Look for a new version each time PiqX opens.',
                  style: AppText.bodySm.copyWith(color: c.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: c.primaryContainer,
                  foregroundColor: c.onPrimaryFixed,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.system_update_alt_rounded, size: 20),
                label: Text('Check for updates now', style: AppText.labelLg.copyWith(color: c.onPrimaryFixed)),
                onPressed: () {
                  Navigator.pop(context);
                  checkForUpdates(widget.hostContext, widget.service, manual: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
