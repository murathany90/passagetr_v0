import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/utils/pos_label_mapper.dart';

void main() {
  test('labelFor maps canonical POS to Turkish labels', () {
    expect(PosLabelMapper.labelFor('v.'), 'Fiil (v.)');
    expect(PosLabelMapper.labelFor('n.'), 'İsim (n.)');
  });

  test('sortByCanonicalOrder keeps canonical order and appends unknown', () {
    final List<String> sorted = PosLabelMapper.sortByCanonicalOrder(
      <String>['adv.', 'custom', 'v.', 'prep.'],
    );

    expect(sorted, <String>['prep.', 'v.', 'adv.', 'custom']);
  });
}

