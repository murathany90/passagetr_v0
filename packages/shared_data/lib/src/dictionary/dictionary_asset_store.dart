import 'dictionary_asset_store_stub.dart'
    if (dart.library.io) 'dictionary_asset_store_native.dart'
    as impl;

Future<String?> resolveDictionaryDatabasePath({
  String assetPath = 'assets/db/dictionary_local.sqlite',
  String fileName = 'dictionary_local.sqlite',
}) {
  return impl.resolveDictionaryDatabasePath(
    assetPath: assetPath,
    fileName: fileName,
  );
}
