class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<T> items;
  final bool hasMore;
  final int nextOffset;
}
