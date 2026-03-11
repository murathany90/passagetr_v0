import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _findRepoRoot() {
  var current = Directory.current;
  while (true) {
    final melos = File('${current.path}${Platform.pathSeparator}melos.yaml');
    final supabaseDir = Directory(
      '${current.path}${Platform.pathSeparator}supabase',
    );
    if (melos.existsSync() && supabaseDir.existsSync()) {
      return current;
    }

    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError(
        'Repo root could not be resolved from ${Directory.current.path}',
      );
    }
    current = parent;
  }
}

void main() {
  final repoRoot = _findRepoRoot();
  final migrationDir = Directory(
    '${repoRoot.path}${Platform.pathSeparator}supabase${Platform.pathSeparator}migrations',
  );

  test('rewrite migrations 014-028 are present', () {
    final requiredFiles = <String>[
      '202603080014_profiles_user_roles_entitlements.sql',
      '202603080015_auth_claim_helpers_rbac.sql',
      '202603080016_content_access_flags.sql',
      '202603080017_user_grammar_progress.sql',
      '202603080018_user_test_attempts.sql',
      '202603080019_user_daily_stats.sql',
      '202603080020_content_versions.sql',
      '202603080021_content_change_log.sql',
      '202603080022_audit_logs_media_assets.sql',
      '202603080023_sync_rpc_delta_contract.sql',
      '202603080024_auth_helper_security_definer.sql',
      '202603090025_content_delta_scope_expansion.sql',
      '202603090026_progress_event_rpcs.sql',
      '202603090027_admin_console_management_rpcs.sql',
      '202603090028_user_daily_stats_analytics_helpers.sql',
      '202603100029_admin_console_crud_rpcs.sql',
      '202603100030_reading_catalog_access_and_admin_is_pro.sql',
      '202603110031_admin_console_hardening_p1_p2.sql',
      '202603110032_admin_console_stabilization_detail_contracts.sql',
      '202603110033_admin_console_reading_import.sql',
    ];

    final fileNames = migrationDir
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toSet();

    for (final fileName in requiredFiles) {
      expect(fileNames, contains(fileName));
    }
  });

  test('phase 6 analytics migration contains daily stat helpers', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603090028_user_daily_stats_analytics_helpers.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(
      sql,
      contains('create or replace function public.bump_user_daily_stats'),
    );
    expect(
      sql,
      contains('create or replace function public.fetch_user_daily_stats'),
    );
    expect(sql, contains('apply_user_word_progress_event'));
    expect(sql, contains('apply_user_reading_progress_event'));
    expect(sql, contains('apply_user_grammar_progress_event'));
  });

  test('phase 5 admin migration contains management RPCs', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603090027_admin_console_management_rpcs.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('admin_list_users'));
    expect(sql, contains('admin_set_user_access'));
    expect(sql, contains('admin_set_content_publish_state'));
    expect(sql, contains('write_audit_log'));
  });

  test('phase 5 admin CRUD migration contains pack and content RPCs', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603100029_admin_console_crud_rpcs.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('admin_list_packs'));
    expect(sql, contains('admin_upsert_pack'));
    expect(sql, contains('admin_import_words'));
    expect(sql, contains('admin_upsert_reading_passage'));
    expect(sql, contains('admin_upsert_grammar_module'));
    expect(sql, contains('admin_reorder_grammar_modules'));
  });

  test('phase 5.1 reading catalog migration contains access helpers', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603100030_reading_catalog_access_and_admin_is_pro.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('student_list_reading_catalog'));
    expect(sql, contains('pull_content_changes'));
    expect(sql, contains('is_pro'));
    expect(sql, contains('seq_no > 50'));
  });

  test('phase 5.5 admin hardening migration contains paged RPCs and settings', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603110031_admin_console_hardening_p1_p2.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('create table if not exists public.app_settings'));
    expect(sql, contains('admin_list_users_paged'));
    expect(sql, contains('admin_bulk_set_user_access'));
    expect(sql, contains('admin_get_settings'));
    expect(sql, contains('admin_upsert_settings'));
    expect(sql, contains('admin_fetch_dashboard_snapshot'));
    expect(sql, contains('admin_assign_invited_user_access'));
    expect(sql, contains('publish_at timestamptz'));
    expect(sql, contains('unpublish_at timestamptz'));
  });

  test('phase 5.6 admin stabilization migration contains detail RPCs', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603110032_admin_console_stabilization_detail_contracts.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('admin_get_pack_detail'));
    expect(sql, contains('admin_upsert_pack_detail'));
    expect(sql, contains('admin_get_word_detail'));
    expect(sql, contains('admin_upsert_word_detail'));
    expect(sql, contains('admin_get_reading_detail'));
    expect(sql, contains('admin_upsert_reading_detail'));
    expect(sql, contains('admin_get_grammar_module_detail'));
    expect(sql, contains('admin_upsert_grammar_module_detail'));
    expect(sql, contains('admin_count_words_from_html'));
  });

  test('phase 5.7 admin reading import migration contains import wrapper', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603110033_admin_console_reading_import.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('admin_import_readings'));
    expect(sql, contains('admin_upsert_reading_detail'));
    expect(sql, contains('admin.reading.imported'));
  });
}
