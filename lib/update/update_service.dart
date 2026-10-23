import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/matches.dart';

/// A published PiqX release with an installable APK.
class AppRelease {
  const AppRelease({required this.version, required this.apkUrl, required this.notes, required this.pageUrl});

  /// Version without the leading "v", e.g. "1.2.0".
  final String version;
  final Uri apkUrl;
  final String notes;
  final Uri pageUrl;
}

/// Finds, downloads and installs new PiqX versions from the GitHub releases of [githubRepo].
class UpdateService {
  UpdateService({http.Client? client, this.repo = githubRepo}) : _client = client ?? http.Client();

  final http.Client _client;
  final String repo;

  static const _installer = MethodChannel('piqx/installer');
  static const _autoCheckKey = 'updates.autoCheck';
  static const _skippedKey = 'updates.skippedVersion';

  Future<String> currentVersion() async => (await PackageInfo.fromPlatform()).version;

  /// The latest release that has an APK attached, or null when there is none yet.
  Future<AppRelease?> latestRelease() async {
    final res = await _client.get(
      Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
      headers: const {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw HttpException('GitHub releases: HTTP ${res.statusCode}');
    return parseRelease(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  /// Newer release than the installed app, or null when up to date.
  Future<AppRelease?> availableUpdate() async {
    final latest = await latestRelease();
    if (latest == null) return null;
    return isNewer(latest.version, await currentVersion()) ? latest : null;
  }

  /// Downloads the APK into the app cache (shared with the installer through a FileProvider).
  Future<File> download(AppRelease release, {void Function(double progress)? onProgress}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final file = File('${dir.path}/piqx-${release.version}.apk');

    final res = await _client.send(http.Request('GET', release.apkUrl));
    if (res.statusCode != 200) throw HttpException('APK download: HTTP ${res.statusCode}');
    final total = res.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    return file;
  }

  /// Hands the APK to Android's package installer. Android asks the user to allow
  /// installs from PiqX the first time.
  Future<void> install(File apk) => _installer.invokeMethod('installApk', {'path': apk.path});

  Future<bool> autoCheckEnabled() async => (await SharedPreferences.getInstance()).getBool(_autoCheckKey) ?? true;

  Future<void> setAutoCheck(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_autoCheckKey, enabled);

  /// Version the user dismissed with "Later"; automatic checks stay quiet about it.
  Future<String?> skippedVersion() async => (await SharedPreferences.getInstance()).getString(_skippedKey);

  Future<void> skip(String version) async => (await SharedPreferences.getInstance()).setString(_skippedKey, version);
}

/// Reads a GitHub "release" object; null when it has no APK asset.
AppRelease? parseRelease(Map<String, dynamic> json) {
  final tag = json['tag_name'] as String? ?? '';
  final apk = (json['assets'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .where((a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'))
      .firstOrNull;
  if (tag.isEmpty || apk == null) return null;
  return AppRelease(
    version: tag.startsWith('v') ? tag.substring(1) : tag,
    apkUrl: Uri.parse(apk['browser_download_url'] as String),
    notes: (json['body'] as String? ?? '').trim(),
    pageUrl: Uri.parse(json['html_url'] as String? ?? 'https://github.com/$githubRepo/releases'),
  );
}

/// True when dotted version [candidate] is greater than [current] ("1.10.0" > "1.9.3").
bool isNewer(String candidate, String current) {
  List<int> parts(String v) =>
      v.split('+').first.split('.').map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
  final a = parts(candidate), b = parts(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
