import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/src/features/readings/reading_artwork.dart';
import 'package:student_app/src/features/readings/reading_seed_data.dart';

void main() {
  const seed = ReadingSeedData(
    id: 'reading-test',
    summary: 'Summary',
    author: 'Author',
    durationMinutes: 5,
    progressPercent: 0,
    levelBadgeColor: Color(0xFF000000),
    artworkColors: <Color>[Color(0xFF112233), Color(0xFF445566)],
    artworkIcon: Icons.landscape_rounded,
    sections: <ReadingSectionSeed>[],
    focusWords: <ReadingFocusWordSeed>[],
  );

  testWidgets('uses remote cover url when available', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReadingArtwork(
            seed: seed,
            remoteUrl: 'https://example.com/cover.png',
            semanticLabel: 'Reading cover',
            height: 180,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.image, isA<NetworkImage>());
    expect((image.image as NetworkImage).url, 'https://example.com/cover.png');
  });

  testWidgets('falls back without remote cover url', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReadingArtwork(
            seed: seed,
            height: 180,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );

    expect(find.byType(DecoratedBox), findsWidgets);
  });
}
