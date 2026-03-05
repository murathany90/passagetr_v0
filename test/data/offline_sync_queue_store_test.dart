import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/data/local/offline_sync_queue_store.dart';
import 'package:passagetr/domain/value_objects/flashcard_answer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('reading progress merges by max lastIdx and completed OR', () async {
    final OfflineSyncQueueStore store = OfflineSyncQueueStore();

    await store.upsertReadingProgress(
      passageId: 'p1',
      lastIdx: 2,
      completed: false,
      nowMillis: 10,
    );
    await store.upsertReadingProgress(
      passageId: 'p1',
      lastIdx: 1,
      completed: true,
      nowMillis: 20,
    );

    final OfflineSyncSnapshot snapshot = await store.loadSnapshot();
    final OfflineReadingProgressEntry? entry = snapshot.readingByPassage['p1'];
    expect(entry, isNotNull);
    expect(entry!.lastIdx, 2);
    expect(entry.completed, isTrue);
    expect(snapshot.pendingReadingCount, 1);
  });

  test('word events are FIFO and capped with dropped counter', () async {
    final OfflineSyncQueueStore store = OfflineSyncQueueStore();

    for (int i = 0; i < OfflineSyncQueueStore.maxWordEvents + 5; i++) {
      await store.enqueueFlashcardEvent(
        wordId: 'w$i',
        answer: FlashcardAnswer.known,
        nowMillis: i + 1,
      );
    }

    final OfflineSyncSnapshot snapshot = await store.loadSnapshot();
    expect(snapshot.wordEvents.length, OfflineSyncQueueStore.maxWordEvents);
    expect(snapshot.droppedCount, 5);
    expect(snapshot.wordEvents.first.wordId, 'w5');
    expect(snapshot.wordEvents.last.wordId, 'w2004');
  });
}

