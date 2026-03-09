class GrammarProgress {
  const GrammarProgress({
    required this.moduleId,
    required this.pageId,
    required this.lastPageNo,
    required this.completedPages,
    required this.completed,
  });

  final int moduleId;
  final int? pageId;
  final int lastPageNo;
  final int completedPages;
  final bool completed;
}
