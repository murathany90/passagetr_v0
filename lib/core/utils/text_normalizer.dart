String normalizeTypingAnswer(String value) {
  final String lowered = value.toLowerCase().trim();
  return lowered.replaceAll(RegExp(r'\s+'), ' ');
}
