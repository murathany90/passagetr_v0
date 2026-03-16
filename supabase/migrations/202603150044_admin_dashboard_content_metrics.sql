create or replace function public.admin_fetch_dashboard_snapshot(
  p_days integer default 7
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_days integer := case when p_days in (7, 30, 90) then p_days else 7 end;
  v_current_start timestamptz := now() - make_interval(days => v_days);
  v_previous_start timestamptz := now() - make_interval(days => v_days * 2);
  v_total_users integer;
  v_current_users integer;
  v_previous_users integer;
  v_total_pro_users integer;
  v_current_pro_users integer;
  v_previous_pro_users integer;
  v_total_readings integer;
  v_published_readings integer;
  v_ready_mini_tests integer;
  v_ready_covers integer;
  v_ready_linked_words integer;
  v_total_words integer;
  v_published_words integer;
  v_dictionary_matched_words integer;
  v_total_grammar integer;
  v_published_grammar integer;
  v_dictionary_entry_count integer;
  v_total_audits integer;
  v_current_audits integer;
  v_previous_audits integer;
  v_trend jsonb;
  v_settings jsonb;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select count(*)::integer into v_total_users
  from auth.users;

  select count(*)::integer into v_current_users
  from auth.users
  where created_at >= v_current_start;

  select count(*)::integer into v_previous_users
  from auth.users
  where created_at >= v_previous_start
    and created_at < v_current_start;

  select count(distinct e.user_id)::integer into v_total_pro_users
  from public.entitlements e
  where e.plan = 'pro'
    and e.revoked_at is null
    and e.starts_at <= now()
    and (e.expires_at is null or e.expires_at > now());

  select count(distinct e.user_id)::integer into v_current_pro_users
  from public.entitlements e
  where e.plan = 'pro'
    and e.starts_at >= v_current_start;

  select count(distinct e.user_id)::integer into v_previous_pro_users
  from public.entitlements e
  where e.plan = 'pro'
    and e.starts_at >= v_previous_start
    and e.starts_at < v_current_start;

  select count(*)::integer into v_total_readings
  from public.reading_passages;

  select count(*)::integer into v_published_readings
  from public.reading_passages
  where coalesce(is_published, false);

  select count(*)::integer into v_ready_mini_tests
  from public.reading_passages rp
  where exists (
    select 1
    from public.reading_passage_questions question_row
    where question_row.passage_id = rp.id
  );

  select count(*)::integer into v_ready_covers
  from public.reading_passages rp
  where nullif(trim(coalesce(rp.cover_bucket_name, '')), '') is not null
    and nullif(trim(coalesce(rp.cover_storage_path, '')), '') is not null;

  select count(*)::integer into v_ready_linked_words
  from public.reading_passages rp
  where exists (
    select 1
    from public.reading_passage_words link_row
    where link_row.passage_id = rp.id
  );

  select count(*)::integer into v_total_words
  from public.words;

  select count(*)::integer into v_published_words
  from public.words
  where coalesce(is_published, false);

  select count(*)::integer into v_dictionary_matched_words
  from public.words w
  where coalesce(w.is_published, false)
    and exists (
      select 1
      from public.dictionary_entries entry_row
      where entry_row.is_active = true
        and entry_row.en_word_normalized = lower(trim(coalesce(w.en_word, '')))
    );

  select count(*)::integer into v_total_grammar
  from public.gramer_modulleri;

  select count(*)::integer into v_published_grammar
  from public.gramer_modulleri
  where coalesce(is_published, false);

  select count(*)::integer into v_dictionary_entry_count
  from public.dictionary_entries
  where is_active = true;

  select count(*)::integer into v_total_audits
  from public.audit_logs;

  select count(*)::integer into v_current_audits
  from public.audit_logs
  where created_at >= v_current_start;

  select count(*)::integer into v_previous_audits
  from public.audit_logs
  where created_at >= v_previous_start
    and created_at < v_current_start;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'label', to_char(day_bucket.day, 'DD Mon'),
        'value', coalesce(content_counts.value, 0)
      )
      order by day_bucket.day
    ),
    '[]'::jsonb
  )
  into v_trend
  from (
    select generate_series(v_current_start::date, now()::date, interval '1 day')::date as day
  ) as day_bucket
  left join (
    select created_at::date as day, count(*)::integer as value
    from public.audit_logs
    where created_at >= v_current_start
      and action in (
        'admin.reading.created',
        'admin.reading.updated',
        'admin.reading.deleted',
        'admin.reading.cover.set',
        'admin.reading.cover.cleared',
        'admin.reading.focus_words.auto_assigned_v2',
        'admin.reading.focus_words.auto_assigned_v2.bulk',
        'admin.word.created',
        'admin.word.updated',
        'admin.word.deleted',
        'admin.word.imported',
        'admin.word.pack_reclassification.applied',
        'admin.grammar.created',
        'admin.grammar.updated',
        'admin.grammar.deleted',
        'admin.grammar.reordered',
        'content.published'
      )
    group by created_at::date
  ) as content_counts
    on content_counts.day = day_bucket.day;

  v_settings := public.admin_get_settings();

  return jsonb_build_object(
    'window_days', v_days,
    'user_count', jsonb_build_object(
      'total', v_total_users,
      'delta', v_current_users - v_previous_users
    ),
    'pro_user_count', jsonb_build_object(
      'total', v_total_pro_users,
      'delta', v_current_pro_users - v_previous_pro_users
    ),
    'reading_inventory', jsonb_build_object(
      'total', v_total_readings,
      'published_count', v_published_readings
    ),
    'word_inventory', jsonb_build_object(
      'total', v_total_words,
      'published_count', v_published_words
    ),
    'grammar_inventory', jsonb_build_object(
      'total', v_total_grammar,
      'published_count', v_published_grammar
    ),
    'mini_test_coverage', jsonb_build_object(
      'total', v_total_readings,
      'ready_count', v_ready_mini_tests,
      'missing_count', greatest(v_total_readings - v_ready_mini_tests, 0)
    ),
    'cover_coverage', jsonb_build_object(
      'total', v_total_readings,
      'ready_count', v_ready_covers,
      'missing_count', greatest(v_total_readings - v_ready_covers, 0)
    ),
    'linked_word_coverage', jsonb_build_object(
      'total', v_total_readings,
      'ready_count', v_ready_linked_words,
      'missing_count', greatest(v_total_readings - v_ready_linked_words, 0)
    ),
    'dictionary_match_coverage', jsonb_build_object(
      'total', v_published_words,
      'ready_count', v_dictionary_matched_words,
      'missing_count', greatest(v_published_words - v_dictionary_matched_words, 0)
    ),
    'dictionary_entry_count', v_dictionary_entry_count,
    'audit_count', jsonb_build_object(
      'total', v_total_audits,
      'delta', v_current_audits - v_previous_audits
    ),
    'content_trend', v_trend,
    'maintenance_mode', coalesce((v_settings->'general'->>'maintenance_mode')::boolean, false),
    'reading_count', jsonb_build_object(
      'total', v_total_readings,
      'delta', 0
    ),
    'word_count', jsonb_build_object(
      'total', v_total_words,
      'delta', 0
    ),
    'grammar_count', jsonb_build_object(
      'total', v_total_grammar,
      'delta', 0
    ),
    'user_trend', v_trend
  );
end;
$$;

grant execute on function public.admin_fetch_dashboard_snapshot(integer) to authenticated;
