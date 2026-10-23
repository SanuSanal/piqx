import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

const splashDuration = Duration(seconds: 2);

/// Branded launch screen shown for [splashDuration] before [next] replaces it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});

  final WidgetBuilder next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: splashDuration)..forward();
  late final _intro = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(splashDuration, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, _, _) => widget.next(context),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The splash is always dark, whatever theme the app is in.
    const c = PiqxColors.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: c.surface,
      ),
      child: Scaffold(
        backgroundColor: c.surface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Atmospheric glow behind the logo.
            Center(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      c.primaryContainer.withValues(alpha: 0.16),
                      c.secondaryContainer.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _intro,
                child: ScaleTransition(
                  scale: Tween(begin: 0.86, end: 1.0).animate(_intro),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 200,
                        semanticLabel: 'PiqX',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'LIVE FOOTBALL & CRICKET STREAMS',
                        style: AppText.labelMd.copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 48),
                child: Center(
                  child: _ProgressTrack(animation: _controller, colors: c),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.animation, required this.colors});

  final Animation<double> animation;
  final PiqxColors colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 140,
        height: 4,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.12))),
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) => FractionallySizedBox(
                widthFactor: animation.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primaryContainer, colors.secondaryContainer],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
