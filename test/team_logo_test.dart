import 'package:flutter_test/flutter_test.dart';
import 'package:piqx/widgets/match_cards.dart';

void main() {
  const crest = 'https://a.espncdn.com/i/teamlogos/soccer/500/359.png';

  test('dark mode tries the dark football crest first, resized', () {
    expect(espnLogoUrls(crest, dark: true, px: 132), [
      'https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500-dark/359.png&w=132&h=132',
      'https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/359.png&w=132&h=132',
    ]);
  });

  test('light mode and cricket use the standard crest only', () {
    expect(espnLogoUrls(crest, dark: false, px: 96),
        ['https://a.espncdn.com/combiner/i?img=/i/teamlogos/soccer/500/359.png&w=96&h=96']);
    expect(espnLogoUrls('https://a.espncdn.com/i/teamlogos/cricket/500/6.png', dark: true, px: 96),
        ['https://a.espncdn.com/combiner/i?img=/i/teamlogos/cricket/500/6.png&w=96&h=96']);
  });

  test('non-ESPN URLs are used as they are', () {
    expect(espnLogoUrls('https://example.com/a.png', dark: true, px: 96), ['https://example.com/a.png']);
  });
}
