class PassageSentence {
  const PassageSentence({
    required this.id,
    required this.passageId,
    required this.passageTitle,
    required this.idx,
    required this.sentenceEn,
    required this.sentenceTr,
  });

  final String id;
  final String? passageId;
  final String? passageTitle;
  final int idx;
  final String sentenceEn;
  final String? sentenceTr;
}
