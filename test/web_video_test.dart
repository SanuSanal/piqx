import 'package:flutter_test/flutter_test.dart';
import 'package:piqx/widgets/web_video.dart';

void main() {
  test('reads playback reports from the page script', () {
    final playing = VideoPlayback.fromMessage('{"width": 1280, "height": 720}');
    expect(playing.playing, isTrue);
    expect((playing.width, playing.height), (1280, 720));

    // Size not known yet: still playing.
    final unsized = VideoPlayback.fromMessage('{"width": 0, "height": null}');
    expect(unsized.playing, isTrue);
    expect((unsized.width, unsized.height), (0, 0));
  });

  test('null, or anything else, means no video plays', () {
    expect(VideoPlayback.fromMessage('null').playing, isFalse);
    expect(VideoPlayback.fromMessage('[1280, 720]').playing, isFalse);
    expect(VideoPlayback.fromMessage('not json').playing, isFalse);
  });
}
