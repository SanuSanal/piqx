import 'dart:convert';

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

const _webViewChannel = MethodChannel('piqx/webview');

/// Runs [js] as every page and frame of [controller] starts, frames from other sites included,
/// before the page's own scripts. Call before loading the page. False when the device's
/// WebView can't; then [js] only reaches the frames it is run in some other way.
Future<bool> runInAllFrames(WebViewController controller, String js) async {
  final android = controller.platform;
  if (android is! AndroidWebViewController) return false;
  try {
    final added = await _webViewChannel.invokeMethod<bool>(
      'addDocumentStartScript',
      {'webView': android.webViewIdentifier, 'script': js},
    );
    return added ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// Whether a page's video is playing, as [videoPlaybackJs] reports it.
class VideoPlayback {
  const VideoPlayback({required this.playing, this.width = 0, this.height = 0});

  static const stopped = VideoPlayback(playing: false);

  final bool playing;

  /// The playing video's size in pixels; 0 when not known yet.
  final int width;
  final int height;

  /// Reads one report: `{"width": 1280, "height": 720}` while a video plays, `null` when none
  /// does. Anything else counts as none.
  static VideoPlayback fromMessage(String message) {
    try {
      final j = jsonDecode(message);
      if (j is! Map) return stopped;
      int whole(Object? v) => v is num && v.isFinite && v > 0 ? v.round() : 0;
      return VideoPlayback(playing: true, width: whole(j['width']), height: whole(j['height']));
    } catch (_) {
      return stopped;
    }
  }
}

const _videoChannel = 'PiqxVideo';

/// Sends [onChange] each change in whether a video plays in [controller]'s pages, as
/// [videoPlaybackJs] reports it. Register before loading the page.
Future<void> watchVideoPlayback(WebViewController controller, void Function(VideoPlayback) onChange) =>
    controller.addJavaScriptChannel(
      _videoChannel,
      onMessageReceived: (message) => onChange(VideoPlayback.fromMessage(message.message)),
    );

/// Makes the playing video fill the page, hiding everything else, or puts the page back.
String fitVideoJs(bool fit) => 'window.__piqxVideo && __piqxVideo.fit($fit)';

/// Pauses every video on the page, in its frames too.
const pauseVideoJs = 'window.__piqxVideo && __piqxVideo.pause()';

/// Page script, for every frame (see [runInAllFrames]): watches the frame's videos and tells
/// its parent frame, and the top frame tells the [watchVideoPlayback] channel, whether one is
/// playing and its size. A frame whose child frame plays a video counts as playing it, so a
/// player embedded from another site counts too.
///
/// It also answers [fitVideoJs] and [pauseVideoJs]: each frame fits or pauses its own video
/// and passes the request down to the child frame that plays one. Installs once per frame.
const videoPlaybackJs = r'''
(() => {
  if (window.__piqxVideo) return;
  const isTop = window === window.top;
  const STYLE = 'piqx-fit-video';
  const children = new Map(); // child frame's window -> size of the video it plays
  let reported;
  let fitted = null;

  const post = (win, data) => { try { win.postMessage(data, '*'); } catch (_) {} };
  const frameOf = (win) => [...document.querySelectorAll('iframe, frame')].find((f) => f.contentWindow === win);
  const playingVideo = () => [...document.querySelectorAll('video')].find((v) => !v.paused && !v.ended && v.readyState > 2);
  // What plays here: a video of this frame, or the child frame that plays one.
  const current = () => {
    const video = playingVideo();
    if (video) return { target: video, size: { width: video.videoWidth, height: video.videoHeight } };
    for (const [win, size] of children) {
      const frame = frameOf(win);
      if (frame) return { target: frame, size };
      children.delete(win);
    }
    return null;
  };

  const report = () => {
    const now = current();
    if (fitted && now && now.target !== fitted) fit(true);
    const message = JSON.stringify(now ? now.size : null);
    if (message === reported) return;
    reported = message;
    if (!isTop) post(parent, { __piqxVideoReport: now ? now.size : null });
    else try { PiqxVideo.postMessage(message); } catch (_) {}
  };

  const unfit = () => {
    document.getElementById(STYLE)?.remove();
    for (const el of document.querySelectorAll('[data-piqx-fit], [data-piqx-fit-path]')) {
      el.removeAttribute('data-piqx-fit');
      el.removeAttribute('data-piqx-fit-path');
    }
    if (fitted && fitted.contentWindow) post(fitted.contentWindow, { __piqxVideoCommand: 'unfit' });
    fitted = null;
  };
  const fit = (on) => {
    unfit();
    const now = on && current();
    if (!now) return;
    fitted = now.target;
    fitted.setAttribute('data-piqx-fit', '');
    for (let el = fitted.parentElement; el; el = el.parentElement) el.setAttribute('data-piqx-fit-path', '');
    const style = document.createElement('style');
    style.id = STYLE;
    style.textContent = `
      html, body { overflow: hidden !important; background: #000 !important; }
      [data-piqx-fit-path] { transform: none !important; filter: none !important; backdrop-filter: none !important;
        perspective: none !important; contain: none !important; will-change: auto !important; }
      [data-piqx-fit-path] > :not([data-piqx-fit-path]):not([data-piqx-fit]) { visibility: hidden !important; }
      [data-piqx-fit] { position: fixed !important; inset: 0 !important; width: 100vw !important; height: 100vh !important;
        min-width: 0 !important; min-height: 0 !important; max-width: none !important; max-height: none !important;
        margin: 0 !important; padding: 0 !important; border: 0 !important; transform: none !important;
        z-index: 2147483647 !important; visibility: visible !important; background: #000 !important;
        object-fit: contain !important; }`;
    document.documentElement.appendChild(style);
    if (fitted.contentWindow) post(fitted.contentWindow, { __piqxVideoCommand: 'fit' });
  };
  const pause = () => {
    for (const video of document.querySelectorAll('video')) video.pause();
    for (const frame of document.querySelectorAll('iframe, frame')) {
      if (frame.contentWindow) post(frame.contentWindow, { __piqxVideoCommand: 'pause' });
    }
  };

  window.__piqxVideo = { fit, pause };
  for (const type of ['play', 'playing', 'pause', 'ended', 'emptied', 'loadedmetadata']) {
    document.addEventListener(type, report, true);
  }
  addEventListener('message', (e) => {
    const d = e.data;
    if (!d || typeof d !== 'object' || !e.source) return;
    if ('__piqxVideoReport' in d) {
      if (d.__piqxVideoReport) children.set(e.source, d.__piqxVideoReport);
      else children.delete(e.source);
      report();
    } else if (!isTop && e.source === parent) {
      const command = d.__piqxVideoCommand;
      if (command === 'fit' || command === 'unfit') fit(command === 'fit');
      else if (command === 'pause') pause();
    }
  });
  report();
})();
''';
