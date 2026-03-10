class GrammarModule {
  const GrammarModule({
    required this.id,
    required this.title,
    required this.pageCount,
    this.description = '',
  });

  final int id;
  final String title;
  final int pageCount;
  final String description;
}
