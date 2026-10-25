import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// The app runs in portrait; only full-screen web video turns to landscape.
Future<void> lockPortrait() => SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);

/// When the user taps a video's full-screen button, shows it over the app in landscape, and
/// returns to portrait when it leaves full screen. Videos never go full screen by themselves.
Future<void> enableLandscapeFullscreen(WebViewController controller, BuildContext Function() context) async {
  final android = controller.platform;
  if (android is! AndroidWebViewController) return;
  var showing = false;
  await android.setCustomWidgetCallbacks(
    onShowCustomWidget: (video, exitFullscreen) {
      showing = true;
      Navigator.of(context()).push(PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => _FullscreenVideo(video: video, onBack: exitFullscreen),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ));
    },
    onHideCustomWidget: () {
      if (!showing) return;
      showing = false;
      Navigator.of(context()).pop();
    },
  );
}

class _FullscreenVideo extends StatefulWidget {
  const _FullscreenVideo({required this.video, required this.onBack});

  final Widget video;

  /// Asks the page to leave full screen; the WebView then hides this route.
  final VoidCallback onBack;

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    lockPortrait();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: ColoredBox(color: Colors.black, child: widget.video),
    );
  }
}
