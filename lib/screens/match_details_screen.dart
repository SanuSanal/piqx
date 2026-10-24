import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/matches.dart';
import '../theme/app_theme.dart';

/// Hides ESPN's own site header and nav (espn.com football, espn.in cricket); the screen's
/// header already credits ESPN. The cricket score strip sticks below that header, so it's
/// pinned to the top instead.
const _hideEspnHeader = r'''
(() => {
  if (document.getElementById('piqx-hide-header')) return;
  const style = document.createElement('style');
  style.id = 'piqx-hide-header';
  style.textContent = 'header.Site__Header__Wrapper, header#global-header { display: none !important; }'
    + ' .gp__cricket__gameHeader { top: 0 !important; }';
  (document.head || document.documentElement).appendChild(style);
})();
''';

/// A match's ESPN page (scorecard, commentary) in a WebView.
class MatchDetailsScreen extends StatefulWidget {
  const MatchDetailsScreen({super.key, required this.match, required this.url});

  final Match match;
  final String url;

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(PiqxColors.dark.surfaceContainerLowest)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _hideSiteHeader(),
          onProgress: (p) {
            setState(() => _progress = p);
            _hideSiteHeader();
          },
          onPageFinished: (_) => _hideSiteHeader(),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Injected as the page loads (it's a no-op once the style is in), so the header barely flashes.
  void _hideSiteHeader() => _controller.runJavaScript(_hideEspnHeader).catchError((_) {});

  /// System back walks back through the page's history first, then leaves the screen.
  Future<void> _onBack(bool didPop, Object? _) async {
    if (didPop) return;
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final m = widget.match;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: c.surface,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: _onBack,
        child: Scaffold(
          backgroundColor: c.surface,
          body: SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Back',
                          icon: Icon(Icons.arrow_back, size: 24, color: c.onSurfaceVariant),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${m.home.name} vs ${m.away.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.headlineSm.copyWith(color: c.onSurface, fontWeight: FontWeight.w700)),
                              Text('${m.league} • ESPN',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.labelSm.copyWith(color: c.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _controller),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
