class GrammarModule {
  const GrammarModule({
    required this.id,
    required this.sortOrder,
    required this.title,
    required this.pageCount,
    this.icon = 'menu_book',
    this.color = '#4776E6',
  });

  final int id;
  final int sortOrder;
  final String title;
  final int pageCount;
  final String icon;
  final String color;
}
