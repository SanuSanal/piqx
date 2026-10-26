import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/block_rules.dart';
import '../data/matches.dart';
import '../theme/app_theme.dart';
import '../widgets/live_badge.dart';
import '../widgets/picture_in_picture.dart';
import '../widgets/toast.dart';
import '../widgets/web_api_filter.dart';
import '../widgets/web_api_hook.dart';
import '../widgets/web_video.dart';

/// Page script: on a channel page (an address with an `@handle`, e.g. `/@LaLiga/videos`), hides
/// every element whose own text is the handle, ignoring case ("LALIGA", "ICC"). Nothing about the
/// page is fixed in advance: the handle is read from the current address and the page is
/// re-checked whenever it changes, so it keeps working as YouTube renders more content or moves
/// between pages without a reload. Elements are shown again once the address has no handle.
const _hideChannelNameJs = r"""
(() => {
  if (window.__piqxHideChannelName) return;
  window.__piqxHideChannelName = true;
  const ownText = (el) => [...el.childNodes].filter((n) => n.nodeType === 3).map((n) => n.textContent).join('').trim().toLowerCase();
  const handle = () => {
    const m = location.pathname.match(/\/@([^\/?#]+)/);
    return m ? decodeURIComponent(m[1]).toLowerCase() : null;
  };
  let queued = false;
  const check = () => {
    queued = false;
    if (!document.body) return;
    const name = handle();
    for (const el of document.querySelectorAll('[data-piqx-hidden]')) {
      if (name && ownText(el) === name) continue;
      el.removeAttribute('data-piqx-hidden');
      el.style.removeProperty('display');
    }
    if (!name) return;
    const texts = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    for (let node = texts.nextNode(); node; node = texts.nextNode()) {
      const el = node.parentElement;
      if (!el || el.hasAttribute('data-piqx-hidden') || node.textContent.trim().toLowerCase() !== name) continue;
      if (ownText(el) !== name) continue;
      el.setAttribute('data-piqx-hidden', '');
      el.style.setProperty('display', 'none', 'important');
    }
  };
  const queue = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(check);
  };
  new MutationObserver(queue).observe(document.documentElement, { childList: true, subtree: true, characterData: true });
  queue();
})();
""";

/// "Matches - WebView Player Feed" from Stitch.
class StreamScreen extends StatefulWidget {
  const StreamScreen({
    super.key,
    required this.sport,
    this.match,
    this.url,
    this.blockRules = BlockRules.none,
    this.onApiCall,
  });

  final Sport sport;
  final Match? match;

  /// Stream page for [sport]; the placeholder shows while there is none.
  final String? url;

  /// Redirects and API calls the page may not make; a toast says when one is blocked.
  final BlockRules blockRules;

  /// Receives the API calls the page makes; null leaves the page unwatched.
  final WebApiCallback? onApiCall;

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  WebViewController? _controller;
  int _progress = 0;

  String? get _url => widget.url;

  late final String? _apiFilterJs =
      widget.blockRules.apiCalls.isEmpty ? null : apiFilterJs(widget.blockRules.apiCalls);

  @override
  void initState() {
    super.initState();
    final url = _url;
    if (url != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(PiqxColors.dark.surfaceContainerLowest)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) => _allowNavigation(Uri.parse(url), request),
            onPageStarted: (_) => _injectPageScripts(),
            onProgress: (p) {
              setState(() => _progress = p);
              _injectPageScripts();
            },
            onPageFinished: (_) => _injectPageScripts(),
          ),
        );
      final onApiCall = widget.onApiCall;
      if (onApiCall != null) watchApiCalls(_controller!, onApiCall);
      watchBlockedApiCalls(_controller!, (call) => _onBlocked('Blocked a call to ${Uri.tryParse(call)?.host ?? call}'));
      watchVideoPlayback(_controller!, _onVideo);
      final pip = PictureInPicture.instance;
      pip.active.addListener(_onPipChanged);
      pip.onDismissed = _pauseVideo;
      _load(Uri.parse(url));
      enableLandscapeFullscreen(_controller!, () => context);
    }
  }

  @override
  void dispose() {
    if (_controller != null) {
      final pip = PictureInPicture.instance;
      pip.active.removeListener(_onPipChanged);
      if (pip.onDismissed == _pauseVideo) pip.onDismissed = null;
      pip.setVideo(playing: false);
    }
    super.dispose();
  }

  /// Adds the video script to every frame before the page loads, so players embedded from
  /// other sites are seen too.
  Future<void> _load(Uri url) async {
    final controller = _controller!;
    await runInAllFrames(controller, videoPlaybackJs);
    await controller.loadRequest(url);
  }

  /// Showing in the floating window, where only the video shows.
  bool _inPip = false;

  /// While a video plays, leaving the app opens it in a floating window.
  void _onVideo(VideoPlayback video) =>
      PictureInPicture.instance.setVideo(playing: video.playing, width: video.width, height: video.height);

  /// In the floating window the header and margins go, and the page fits its playing video
  /// to the window; back in the app, both return.
  void _onPipChanged() {
    final active = PictureInPicture.instance.active.value;
    if (!mounted || active == _inPip) return;
    setState(() => _inPip = active);
    _controller?.runJavaScript(fitVideoJs(active)).catchError((_) {});
  }

  /// Closing the floating window stops the video rather than leaving it playing unseen.
  void _pauseVideo() => _controller?.runJavaScript(pauseVideoJs).catchError((_) {});

  static const _blockedToastFor = Duration(seconds: 3);
  DateTime? _blockedToastAt;

  /// Shows [message] about something blocked. Pages often try several at once, so while that
  /// toast is still up, further blocks don't show it again.
  void _onBlocked(String message) {
    final now = DateTime.now();
    final last = _blockedToastAt;
    if (!mounted || _inPip || (last != null && now.difference(last) < _blockedToastFor)) return;
    _blockedToastAt = now;
    showToast(context, message, duration: _blockedToastFor);
  }

  /// Keeps the page on the stream's site when [StreamScreen.blockRules] say so. Frames inside
  /// the page (often the player itself) may load from anywhere.
  NavigationDecision _allowNavigation(Uri start, NavigationRequest request) {
    final to = Uri.tryParse(request.url);
    if (!request.isMainFrame || to == null || !widget.blockRules.blocksNavigation(start, to)) {
      return NavigationDecision.navigate;
    }
    _onBlocked('Blocked a redirect to ${to.host.isEmpty ? to.scheme : to.host}');
    return NavigationDecision.prevent;
  }

  /// Injected as the page loads, so the channel name never shows and filtered API calls never
  /// go out; each script installs once per page and then keeps itself up to date. The video
  /// script is here too for WebViews that can't run it in every frame.
  void _injectPageScripts() {
    final scripts = [_hideChannelNameJs, ?_apiFilterJs, videoPlaybackJs, if (widget.onApiCall != null) apiCallHookJs];
    for (final js in scripts) {
      _controller?.runJavaScript(js).catchError((_) {});
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
                padding: _inPip ? EdgeInsets.zero : EdgeInsets.fromLTRB(16, topInset + 64 + 16, 16, 16 + bottomInset),
                child: _controller == null
                    ? _WebViewPlaceholder(sport: widget.sport, title: title)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(_inPip ? 0 : 12),
                        child: Stack(
                          children: [
                            WebViewWidget(controller: _controller!),
                            if (_progress < 100 && !_inPip)
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
              if (!_inPip)
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
