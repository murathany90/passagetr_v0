import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:student_app/src/core/tts/student_tts_controller.dart';
import 'package:student_app/src/core/tts/student_tts_engine.dart';

void main() {
  group('StudentTtsController', () {
    test('playWord starts speaking and stop resets state', () async {
      final engine = _FakeStudentTtsEngine();
      final controller = StudentTtsController(engine: engine);
      final word = const WordEntry(
        id: 'word-1',
        packId: 'pack-1',
        enWord: 'orbit',
        trMeaning: 'yorunge',
        pos: 'n.',
      );

      final playFuture = controller.playWord(word: word);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isSpeaking, isTrue);
      expect(controller.state.activeTarget, StudentTtsTarget.word);
      expect(controller.state.activeWordId, 'word-1');
      expect(engine.spokenTexts, ['orbit']);

      final stopResult = await controller.stop();
      expect(stopResult, StudentTtsActionResult.stopped);
      expect(controller.state.isSpeaking, isFalse);
      expect(controller.state.activeTarget, isNull);

      engine.completeCurrent();
      await playFuture;
    });

    test('playPassage advances sentence queue in order', () async {
      final engine = _FakeStudentTtsEngine();
      final controller = StudentTtsController(engine: engine);

      final playFuture = controller.playPassage(
        readingId: 'reading-1',
        segments: const <StudentTtsPassageSegment>[
          StudentTtsPassageSegment(sentenceIndex: 0, text: 'First sentence.'),
          StudentTtsPassageSegment(sentenceIndex: 1, text: 'Second sentence.'),
        ],
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.activeTarget, StudentTtsTarget.passage);
      expect(controller.state.activeSentenceIndex, 0);
      expect(engine.spokenTexts, ['First sentence.']);

      engine.completeCurrent();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.activeSentenceIndex, 1);
      expect(engine.spokenTexts, ['First sentence.', 'Second sentence.']);

      engine.completeCurrent();
      final result = await playFuture;

      expect(result, StudentTtsActionResult.started);
      expect(controller.state.isSpeaking, isFalse);
      expect(controller.state.activeTarget, isNull);
    });

    test('new playback interrupts previous playback', () async {
      final engine = _FakeStudentTtsEngine();
      final controller = StudentTtsController(engine: engine);
      final word = const WordEntry(
        id: 'word-1',
        packId: 'pack-1',
        enWord: 'orbit',
        trMeaning: 'yorunge',
        pos: 'n.',
      );

      final firstFuture = controller.playWord(word: word);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.activeTarget, StudentTtsTarget.word);
      expect(engine.stopCount, 1);

      final secondFuture = controller.playSentence(
        readingId: 'reading-1',
        sentenceIndex: 3,
        text: 'The satellite stays in orbit.',
      );
      await Future<void>.delayed(Duration.zero);

      expect(engine.stopCount, greaterThanOrEqualTo(2));
      expect(controller.state.activeTarget, StudentTtsTarget.sentence);
      expect(controller.state.activeSentenceIndex, 3);
      expect(engine.spokenTexts.last, 'The satellite stays in orbit.');

      engine.completeAt(0);
      engine.completeCurrent();

      await firstFuture;
      await secondFuture;
    });

    test('unsupported engine surfaces unavailable state and message', () async {
      final engine = _FakeStudentTtsEngine(
        availability: StudentTtsAvailability.unsupported,
      );
      final controller = StudentTtsController(engine: engine);

      final result = await controller.playSentence(
        readingId: 'reading-1',
        sentenceIndex: 0,
        text: 'Example sentence.',
      );

      expect(result, StudentTtsActionResult.unavailable);
      expect(controller.state.isUnavailable, isTrue);
      expect(controller.state.errorMessage, isNotEmpty);
    });
  });
}

class _FakeStudentTtsEngine implements StudentTtsEngine {
  _FakeStudentTtsEngine({
    this.availability = StudentTtsAvailability.available,
  });

  final StudentTtsAvailability availability;

  final List<String> spokenTexts = <String>[];
  final List<Completer<void>> _speakCompleters = <Completer<void>>[];
  int stopCount = 0;

  @override
  Future<StudentTtsAvailability> ensureInitialized() async => availability;

  @override
  Future<void> speak(String text) {
    spokenTexts.add(text);
    final completer = Completer<void>();
    _speakCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  Future<void> dispose() async {}

  void completeCurrent() {
    for (var index = 0; index < _speakCompleters.length; index++) {
      if (_speakCompleters[index].isCompleted) {
        continue;
      }
      _speakCompleters[index].complete();
      return;
    }
  }

  void completeAt(int index) {
    if (index < 0 || index >= _speakCompleters.length) {
      return;
    }
    final completer = _speakCompleters[index];
    if (!completer.isCompleted) {
      completer.complete();
    }
  }
}
