import 'dart:async';

import 'package:flutter/widgets.dart';

import 'matches.dart';
import 'scores_repository.dart';

/// Holds today's matches and keeps them fresh: every minute while something is live,
/// every five minutes otherwise, and straight away when the app comes back to the foreground.
class ScoresController extends ChangeNotifier with WidgetsBindingObserver {
  ScoresController(this._repository, {this.autoRefresh = true}) {
    if (autoRefresh) WidgetsBinding.instance.addObserver(this);
  }

  final ScoresRepository _repository;
  final bool autoRefresh;

  static const liveInterval = Duration(minutes: 1);
  static const idleInterval = Duration(minutes: 5);

  List<Match> _matches = const [];
  bool _loading = false;
  Object? _error;
  DateTime? _updatedAt;
  Timer? _timer;
  bool _disposed = false;

  List<Match> get matches => _matches;
  bool get loading => _loading;

  /// Error from the last refresh; [matches] keeps the last good data.
  Object? get error => _error;
  DateTime? get updatedAt => _updatedAt;
  bool get hasLoaded => _updatedAt != null;

  List<Match> forSport(Sport sport) => _matches.where((m) => m.sport == sport).toList();

  Future<void> refresh() async {
    if (_loading) return;
    _timer?.cancel();
    _loading = true;
    _notify();
    try {
      _matches = await _repository.fetchToday();
      _error = null;
      _updatedAt = DateTime.now();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      _notify();
      _schedule();
    }
  }

  void _schedule() {
    if (!autoRefresh || _disposed) return;
    _timer?.cancel();
    _timer = Timer(_matches.any((m) => m.isLive) ? liveInterval : idleInterval, refresh);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (autoRefresh) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
