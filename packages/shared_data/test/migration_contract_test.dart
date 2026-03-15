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
      '202603130036_word_favorites.sql',
      '202603130037_admin_ai_reading_assistant.sql',
      '202603140038_word_pack_reclassification.sql',
      '202603140039_word_pack_reclassification_preview_hotfix.sql',
      '202603140040_word_pack_reclassification_apply_hotfix.sql',
      '202603140041_reading_ai_questions_and_cover_pipeline.sql',
      '202603150042_reading_ai_run_controls.sql',
      '202603150043_cover_backfill_failure_rate_guard.sql',
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

  test(
    'phase 5.5 admin hardening migration contains paged RPCs and settings',
    () {
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
    },
  );

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

  test('phase 5.8 focus word bulk migration contains repaired RPCs', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603120035_admin_focus_word_bulk_and_filter_fixes.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('admin_suggest_reading_focus_words_v2'));
    expect(sql, contains('admin_autolink_all_reading_focus_words_v2'));
    expect(sql, contains('sample_failures'));
    expect(sql, contains('admin_list_reading_passages_paged'));
    expect(
      sql,
      contains('coalesce((select count(*)::integer from filtered), 0)'),
    );
  });

  test('word favorites migration contains table and sync RPC', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603130036_word_favorites.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(
      sql,
      contains('create table if not exists public.user_word_favorites'),
    );
    expect(
      sql,
      contains(
        'create or replace function public.apply_user_word_favorite_event',
      ),
    );
    expect(sql, contains('mark_sync_event_processed'));
    expect(
      sql,
      contains(
        'grant execute on function public.apply_user_word_favorite_event',
      ),
    );
  });

  test('phase 11 AI reading assistant migration extends reading detail', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603130037_admin_ai_reading_assistant.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('reading_passage_questions'));
    expect(sql, contains('ai_generated boolean not null default false'));
    expect(sql, contains('ai_generation_meta jsonb'));
    expect(sql, contains('admin_get_reading_detail'));
    expect(sql, contains("'questions'"));
    expect(sql, contains('admin_upsert_reading_detail'));
    expect(sql, contains("'question_count'"));
  });

  test(
    'word pack reclassification migration contains preview and apply RPCs',
    () {
      final migrationFile = File(
        '${migrationDir.path}${Platform.pathSeparator}202603140038_word_pack_reclassification.sql',
      );
      final sql = migrationFile.readAsStringSync();

      expect(sql, contains('word_pack_reclassification_runs'));
      expect(sql, contains('word_pack_reclassification_items'));
      expect(sql, contains('admin_preview_word_pack_reclassification'));
      expect(sql, contains('admin_apply_word_pack_reclassification'));
      expect(sql, contains('tie_break_lowest_set'));
      expect(sql, contains('no_linked_passages'));
      expect(sql, contains('service_role'));
    },
  );

  test('word pack reclassification hotfix migration prefers column names', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603140039_word_pack_reclassification_preview_hotfix.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('admin_preview_word_pack_reclassification'));
    expect(sql, contains('#variable_conflict use_column'));
    expect(
      sql,
      contains(
        'grant execute on function public.admin_preview_word_pack_reclassification',
      ),
    );
  });

  test('word pack reclassification apply hotfix handles duplicate merges', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603140040_word_pack_reclassification_apply_hotfix.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('admin_apply_word_pack_reclassification'));
    expect(sql, contains('user_word_progress'));
    expect(sql, contains('user_word_favorites'));
    expect(sql, contains('reading_passage_words'));
    expect(sql, contains('merged_duplicate_count'));
  });

  test('phase 11.3 reading AI migration contains cover and batch pipeline', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603140041_reading_ai_questions_and_cover_pipeline.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('cover_media_asset_id'));
    expect(sql, contains('cover_bucket_name'));
    expect(sql, contains('cover_storage_path'));
    expect(sql, contains('cover_alt_text'));
    expect(sql, contains('cover_generation_meta'));
    expect(sql, contains('reading_ai_runs'));
    expect(sql, contains('reading_ai_run_items'));
    expect(sql, contains('question_backfill'));
    expect(sql, contains('cover_backfill'));
    expect(sql, contains('reading-covers'));
    expect(sql, contains('admin_set_reading_cover'));
    expect(sql, contains('admin_clear_reading_cover'));
    expect(sql, contains('admin_create_reading_ai_run'));
    expect(sql, contains('admin_get_reading_ai_run'));
    expect(sql, contains('admin_claim_reading_ai_run_items'));
    expect(sql, contains('admin_mark_reading_ai_run_item'));
    expect(sql, contains('question_count'));
    expect(sql, contains('has_cover'));
  });

  test('phase 11.4 reading AI controls migration contains paused run controls', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603150042_reading_ai_run_controls.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains("status in ('queued', 'running', 'paused', 'completed', 'failed', 'cancelled')"));
    expect(sql, contains('pause_reason text'));
    expect(sql, contains('last_error_message text'));
    expect(sql, contains('consecutive_failure_count integer not null default 0'));
    expect(sql, contains('admin_list_active_reading_ai_runs'));
    expect(sql, contains('admin_control_reading_ai_run'));
    expect(sql, contains("'auto_failure_threshold'"));
    expect(sql, contains("status = 'paused'"));
  });

  test('phase 11.4.1 cover backfill guard migration contains failure rate pause', () {
    final migrationFile = File(
      '${migrationDir.path}${Platform.pathSeparator}202603150043_cover_backfill_failure_rate_guard.sql',
    );
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('admin_mark_reading_ai_run_item'));
    expect(sql, contains('auto_failure_rate_threshold'));
    expect(sql, contains('v_processed_count >= 10'));
    expect(sql, contains('(v_failed_count * 100) >= (v_processed_count * 60)'));
    expect(sql, contains('last_error_message = null'));
  });
}
