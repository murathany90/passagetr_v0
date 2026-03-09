enum CachePolicy {
  authContext(Duration(seconds: 60)),
  publishedContent(Duration(minutes: 5)),
  adminList(Duration(seconds: 30));

  const CachePolicy(this.ttl);

  final Duration ttl;
}
