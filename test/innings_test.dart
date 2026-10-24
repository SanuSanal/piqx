import 'package:flutter_test/flutter_test.dart';
import 'package:piqx/widgets/match_cards.dart';

void main() {
  test('innings splits into runs and the bracketed overs', () {
    expect(splitInnings('127/3 (15.5/20 ov)'), ('127/3', '15.5/20 ov'));
    expect(splitInnings('168/4 (17.2/20 ov, target 166)'), ('168/4', '17.2/20 ov, target 166'));
  });

  test('a score without overs is all runs; nothing is nothing', () {
    expect(splitInnings('113'), ('113', null));
    expect(splitInnings('  '), (null, null));
    expect(splitInnings(null), (null, null));
  });
}
