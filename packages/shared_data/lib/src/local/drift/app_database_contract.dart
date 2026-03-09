class AppDatabaseContract {
  const AppDatabaseContract._();

  static const schemaVersion = 2;
  static const databaseFileName = 'passagetr_v2_local.db';
  static const syncMetaTable = 'sync_meta';
  static const syncOutboxTable = 'sync_outbox';
  static const contentDeltaTable = 'content_delta_cache';
  static const contentEntityTable = 'content_entity_cache';
  static const progressSnapshotTable = 'progress_snapshot_cache';
  static const pendingStatus = 'pending';
  static const syncedStatus = 'synced';
  static const failedStatus = 'failed';
  static const deadLetterStatus = 'dead_letter';
}
