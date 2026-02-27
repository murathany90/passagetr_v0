import 'reading_passage.dart';
import 'user_reading_progress.dart';

class ReadingResumeItem {
  const ReadingResumeItem({
    required this.passage,
    required this.progress,
  });

  final ReadingPassage passage;
  final UserReadingProgress progress;
}
