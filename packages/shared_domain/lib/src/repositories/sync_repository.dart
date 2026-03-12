import 'package:shared_core/shared_core.dart';

import '../value_objects/sync_scope.dart';

abstract interface class SyncRepository {
  Future<AppResult<void>> syncIfStale(SyncScope scope);
  Future<AppResult<void>> syncNow(SyncScope scope);
}
