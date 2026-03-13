import 'package:flutter_test/flutter_test.dart';
import 'package:shared_data/shared_data.dart';

void main() {
  test(
    'fetchPacks falls back to preview content when remote lookup throws',
    () async {
      final repository = FoundationPackRepository.preview(
        remoteReaderOverride: () => throw Exception('dns failure'),
      );

      final items = await repository.fetchPacks();

      expect(items, isNotEmpty);
      expect(items.first.id, 'pack-yds-001');
    },
  );
}
