import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/matches.dart';
import '../theme/app_theme.dart';
import '../widgets/live_badge.dart';

/// "Matches - WebView Player Feed" from Stitch.
class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key, required this.sport, this.match});

  final Sport sport;
  final Match? match;

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  WebViewController? _controller;
  int _progress = 0;

  String? get _url => streamUrls[widget.sport];

  @override
  void initState() {
    super.initState();
    final url = _url;
    if (url != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(PiqxColors.dark.surfaceContainerLowest)
        ..setNavigationDelegate(
          NavigationDelegate(onProgress: (p) => setState(() => _progress = p)),
        )
        ..loadRequest(Uri.parse(url));
    }
  }

  Future<void> _share() async {
    final m = widget.match;
    final what = m != null ? '${m.home.name} vs ${m.away.name}' : widget.sport.label.toLowerCase();
    // The page the WebView is on right now, which may differ from the one it started on.
    final streamLink = await _controller?.currentUrl() ?? _url;
    final text = streamLink == null
        ? 'Watch $what live on PiqX!\n\nDownload the app: $appPageUrl'
        : 'Watch $what live on PiqX!\n\nDownload the app: $appPageUrl\n'
            'or go to this link to watch the match: $streamLink';
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Watch $what live on PiqX'));
  }

  /// System back walks back through the stream page's history first, then leaves the screen.
  Future<void> _onBack(bool didPop, Object? _) async {
    if (didPop) return;
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = '${widget.sport.label} Streams';
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: c.surface,
      ),
      child: PopScope(
        canPop: _controller == null,
        onPopInvokedWithResult: _onBack,
        child: Scaffold(
          backgroundColor: c.surface,
          body: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, topInset + 64 + 16, 16, 16 + bottomInset),
                child: _controller == null
                    ? _WebViewPlaceholder(sport: widget.sport, title: title)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            WebViewWidget(controller: _controller!),
                            if (_progress < 100)
                              LinearProgressIndicator(
                                value: _progress / 100,
                                minHeight: 3,
                                color: c.secondaryContainer,
                                backgroundColor: Colors.transparent,
                              ),
                          ],
                        ),
                      ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _StreamHeader(title: title, onBack: () => Navigator.of(context).pop(), onShare: _share),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamHeader extends StatelessWidget {
  const _StreamHeader({required this.title, required this.onBack, required this.onShare});

  final String title;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.85),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      tooltip: 'Back',
                      icon: Icon(Icons.arrow_back, size: 24, color: c.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.headlineSm.copyWith(color: c.onSurface, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.errorContainer.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                PulsingDot(color: c.error, size: 6),
                                const SizedBox(width: 4),
                                Text('LIVE', style: AppText.labelSm.copyWith(fontSize: 11, color: c.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onShare,
                      tooltip: 'Share',
                      icon: Icon(Icons.share_outlined, size: 22, color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebViewPlaceholder extends StatelessWidget {
  const _WebViewPlaceholder({required this.sport, required this.title});

  final Sport sport;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(color: c.outlineVariant.withValues(alpha: 0.6), radius: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surfaceContainerLowest.withValues(alpha: 0.6),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.primaryContainer.withValues(alpha: 0.05),
                Colors.transparent,
                c.secondaryContainer.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.3)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      child: Icon(
                        sport == Sport.cricket ? Icons.sports_cricket : Icons.sports_soccer,
                        size: 32,
                        color: c.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Chip(label: 'WEBVIEW VIEWPORT', bg: c.primaryContainer.withValues(alpha: 0.1), fg: c.primaryText),
                        const SizedBox(width: 8),
                        _Chip(label: 'READY', bg: c.surfaceContainerHigh, fg: c.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: AppText.headlineMd.copyWith(color: c.onSurface, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'External live match feeds and hybrid web content will be embedded and rendered '
                      'in this interactive WebView container.',
                      textAlign: TextAlign.center,
                      style: AppText.bodyMd.copyWith(color: c.onSurfaceVariant, height: 1.625),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppText.labelSm.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0, dash = 6.0, gap = 4.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
}
