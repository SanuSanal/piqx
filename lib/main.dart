import 'package:flutter/material.dart';

import 'data/scores_controller.dart';
import 'data/scores_repository.dart';
import 'data/stream_links.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'update/update_service.dart';
import 'widgets/web_video.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  lockPortrait();
  runApp(const PiqxApp());
}

class PiqxApp extends StatefulWidget {
  const PiqxApp({
    super.key,
    this.repository,
    this.updates,
    this.streams,
    this.autoRefresh = true,
    this.checkUpdatesOnStart = true,
  });

  /// Scores source; ESPN's live feeds when null.
  final ScoresRepository? repository;
  final UpdateService? updates;

  /// Stream links; fetched from GitHub Pages when null.
  final StreamLinks? streams;
  final bool autoRefresh;
  final bool checkUpdatesOnStart;

  @override
  State<PiqxApp> createState() => _PiqxAppState();
}

class _PiqxAppState extends State<PiqxApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  // Start loading scores while the splash is still showing.
  late final _scores = ScoresController(
    widget.repository ?? EspnScoresRepository(),
    autoRefresh: widget.autoRefresh,
  )..refresh();
  late final _updates = widget.updates ?? UpdateService();
  late final _streams = widget.streams ?? (StreamLinks()..load());

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  void dispose() {
    _scores.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PiqX',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: SplashScreen(
        next: (_) => HomeScreen(
          onToggleTheme: _toggleTheme,
          scores: _scores,
          updates: _updates,
          streams: _streams,
          checkUpdatesOnStart: widget.checkUpdatesOnStart,
        ),
      ),
    );
  }
}
