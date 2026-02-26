enum FlashcardAnswer {
  known('known'),
  unsure('unsure'),
  unknown('unknown');

  const FlashcardAnswer(this.value);

  final String value;
}
