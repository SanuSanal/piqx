import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Signal-red LIVE pill with a pulsing dot.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.live,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: c.live.withValues(alpha: 0.45), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingDot(color: c.onLive, size: 6),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.labelSm.copyWith(color: c.onLive, fontFamily: AppText.mono),
          ),
        ],
      ),
    );
  }
}

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Opacity(
              opacity: 1 - _controller.value,
              child: Transform.scale(scale: 1 + _controller.value, child: child),
            ),
            child: dot,
          ),
          dot,
        ],
      ),
    );
  }
}
