import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android picture-in-picture: while a video plays, leaving the app (Home, or switching apps)
/// shrinks it into a floating window over other apps instead of hiding it. Android 8+, on
/// devices that have it; elsewhere nothing happens.
class PictureInPicture {
  PictureInPicture._() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'changed':
          active.value = call.arguments == true;
        case 'dismissed':
          onDismissed?.call();
      }
    });
  }

  static final instance = PictureInPicture._();

  static const _channel = MethodChannel('piqx/pip');

  /// Whether the app is showing in the floating window right now.
  final active = ValueNotifier(false);

  /// Called when the user closes the floating window, which leaves the app in the background.
  VoidCallback? onDismissed;

  /// Says whether a video is playing, so leaving the app should open the window, and the
  /// video's size in pixels, which shapes it (16:9 when unknown).
  Future<void> setVideo({required bool playing, int width = 0, int height = 0}) async {
    try {
      await _channel.invokeMethod<bool>('setVideo', {'playing': playing, 'width': width, 'height': height});
    } on MissingPluginException {
      // Not Android.
    } on PlatformException {
      // The window can't be set up; the app just goes to the background as before.
    }
  }
}
