create or replace function public.apply_user_word_progress_event(
  p_event_id text,
  p_word_id uuid,
  p_answer text,
  p_seen_count_delta int default 1,
  p_correct_count_delta int default 0,
  p_wrong_count_delta int default 0,
  p_mastery_delta int default 0
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted boolean;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  if p_answer not in ('known', 'unsure', 'unknown') then
    raise exception 'invalid_answer';
  end if;

  v_inserted := public.mark_sync_event_processed(
    p_event_id,
    'user_word_progress',
    p_word_id::text
  );

  if not v_inserted then
    return;
  end if;

  insert into public.user_word_progress (
    user_id,
    word_id,
    mastery,
    seen_count,
    correct_count,
    wrong_count,
    last_seen_at,
    last_answer
  )
  values (
    auth.uid(),
    p_word_id,
    greatest(0, least(100, coalesce(p_mastery_delta, 0))),
    greatest(0, coalesce(p_seen_count_delta, 0)),
    greatest(0, coalesce(p_correct_count_delta, 0)),
    greatest(0, coalesce(p_wrong_count_delta, 0)),
    now(),
    p_answer
  )
  on conflict (user_id, word_id) do update
  set mastery = greatest(0, least(100, public.user_word_progress.mastery + coalesce(p_mastery_delta, 0))),
      seen_count = greatest(0, public.user_word_progress.seen_count + coalesce(p_seen_count_delta, 0)),
      correct_count = greatest(0, public.user_word_progress.correct_count + coalesce(p_correct_count_delta, 0)),
      wrong_count = greatest(0, public.user_word_progress.wrong_count + coalesce(p_wrong_count_delta, 0)),
      last_seen_at = now(),
      last_answer = p_answer;
end;
$$;

create or replace function public.apply_user_grammar_progress_event(
  p_event_id text,
  p_module_id bigint,
  p_page_id bigint default null,
  p_last_page_no int default 0,
  p_completed_pages int default 0,
  p_completed boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted boolean;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  v_inserted := public.mark_sync_event_processed(
    p_event_id,
    'user_grammar_progress',
    p_module_id::text
  );

  if not v_inserted then
    return;
  end if;

  insert into public.user_grammar_progress (
    user_id,
    module_id,
    page_id,
    completed_pages,
    last_page_no,
    completed
  )
  values (
    auth.uid(),
    p_module_id,
    p_page_id,
    greatest(0, coalesce(p_completed_pages, 0)),
    greatest(0, coalesce(p_last_page_no, 0)),
    coalesce(p_completed, false)
  )
  on conflict (user_id, module_id) do update
  set page_id = coalesce(excluded.page_id, public.user_grammar_progress.page_id),
      completed_pages = greatest(public.user_grammar_progress.completed_pages, excluded.completed_pages),
      last_page_no = greatest(public.user_grammar_progress.last_page_no, excluded.last_page_no),
      completed = public.user_grammar_progress.completed or excluded.completed;
end;
$$;

create or replace function public.apply_user_test_attempt_event(
  p_event_id text,
  p_source_type text,
  p_source_id text,
  p_score int default 0,
  p_correct_count int default 0,
  p_wrong_count int default 0,
  p_payload_json jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted boolean;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  v_inserted := public.mark_sync_event_processed(
    p_event_id,
    'user_test_attempts',
    p_source_id
  );

  if not v_inserted then
    return;
  end if;

  insert into public.user_test_attempts (
    user_id,
    source_type,
    source_id,
    score,
    correct_count,
    wrong_count,
    payload_json
  )
  values (
    auth.uid(),
    p_source_type,
    p_source_id,
    greatest(0, coalesce(p_score, 0)),
    greatest(0, coalesce(p_correct_count, 0)),
    greatest(0, coalesce(p_wrong_count, 0)),
    coalesce(p_payload_json, '{}'::jsonb)
  );
end;
$$;

grant execute on function public.apply_user_word_progress_event(text, uuid, text, int, int, int, int) to authenticated;
grant execute on function public.apply_user_grammar_progress_event(text, bigint, bigint, int, int, boolean) to authenticated;
grant execute on function public.apply_user_test_attempt_event(text, text, text, int, int, int, jsonb) to authenticated;
