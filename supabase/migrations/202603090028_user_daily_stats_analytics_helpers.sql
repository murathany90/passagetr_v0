create or replace function public.compute_daily_goal_completed(
  p_words_studied int,
  p_readings_completed int,
  p_grammar_completed int
)
returns boolean
language sql
stable
as $$
  select
    coalesce(p_words_studied, 0) >= 10
    or coalesce(p_readings_completed, 0) >= 1
    or coalesce(p_grammar_completed, 0) >= 1;
$$;

create or replace function public.bump_user_daily_stats(
  p_words_delta int default 0,
  p_readings_delta int default 0,
  p_grammar_delta int default 0
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_previous_streak int := 0;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  insert into public.user_daily_stats (
    user_id,
    stat_date,
    words_studied,
    readings_completed,
    grammar_completed,
    goal_completed,
    streak_count
  )
  values (
    auth.uid(),
    current_date,
    greatest(0, coalesce(p_words_delta, 0)),
    greatest(0, coalesce(p_readings_delta, 0)),
    greatest(0, coalesce(p_grammar_delta, 0)),
    public.compute_daily_goal_completed(
      greatest(0, coalesce(p_words_delta, 0)),
      greatest(0, coalesce(p_readings_delta, 0)),
      greatest(0, coalesce(p_grammar_delta, 0))
    ),
    0
  )
  on conflict (user_id, stat_date) do update
  set words_studied = public.user_daily_stats.words_studied + greatest(0, coalesce(p_words_delta, 0)),
      readings_completed = public.user_daily_stats.readings_completed + greatest(0, coalesce(p_readings_delta, 0)),
      grammar_completed = public.user_daily_stats.grammar_completed + greatest(0, coalesce(p_grammar_delta, 0)),
      goal_completed = public.compute_daily_goal_completed(
        public.user_daily_stats.words_studied + greatest(0, coalesce(p_words_delta, 0)),
        public.user_daily_stats.readings_completed + greatest(0, coalesce(p_readings_delta, 0)),
        public.user_daily_stats.grammar_completed + greatest(0, coalesce(p_grammar_delta, 0))
      );

  select coalesce(uds.streak_count, 0)
    into v_previous_streak
  from public.user_daily_stats uds
  where uds.user_id = auth.uid()
    and uds.stat_date = current_date - interval '1 day'
    and uds.goal_completed = true
  limit 1;

  update public.user_daily_stats
  set streak_count = case
        when goal_completed then coalesce(v_previous_streak, 0) + 1
        else 0
      end
  where user_id = auth.uid()
    and stat_date = current_date;
end;
$$;

create or replace function public.fetch_user_daily_stats(
  p_days int default 7
)
returns table (
  stat_date date,
  words_studied int,
  readings_completed int,
  grammar_completed int,
  streak_count int,
  goal_completed boolean
)
language sql
security definer
set search_path = public
as $$
  select
    uds.stat_date,
    uds.words_studied,
    uds.readings_completed,
    uds.grammar_completed,
    uds.streak_count,
    uds.goal_completed
  from public.user_daily_stats uds
  where uds.user_id = auth.uid()
  order by uds.stat_date desc
  limit greatest(coalesce(p_days, 7), 1);
$$;

create or replace function public.apply_user_reading_progress_event(
  p_event_id text,
  p_passage_id uuid,
  p_last_idx int,
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
  v_inserted := public.mark_sync_event_processed(
    p_event_id,
    'user_reading_progress',
    p_passage_id::text
  );

  if not v_inserted then
    return;
  end if;

  insert into public.user_reading_progress (
    user_id,
    passage_id,
    completed,
    last_idx,
    last_seen_at
  )
  values (
    auth.uid(),
    p_passage_id,
    coalesce(p_completed, false),
    greatest(0, coalesce(p_last_idx, 0)),
    now()
  )
  on conflict (user_id, passage_id) do update
  set completed = public.user_reading_progress.completed or coalesce(excluded.completed, false),
      last_idx = greatest(public.user_reading_progress.last_idx, excluded.last_idx),
      last_seen_at = greatest(public.user_reading_progress.last_seen_at, excluded.last_seen_at);

  if coalesce(p_completed, false) then
    perform public.bump_user_daily_stats(
      p_words_delta => 0,
      p_readings_delta => 1,
      p_grammar_delta => 0
    );
  end if;
end;
$$;

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

  perform public.bump_user_daily_stats(
    p_words_delta => greatest(0, coalesce(p_seen_count_delta, 0)),
    p_readings_delta => 0,
    p_grammar_delta => 0
  );
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

  if coalesce(p_completed, false) then
    perform public.bump_user_daily_stats(
      p_words_delta => 0,
      p_readings_delta => 0,
      p_grammar_delta => 1
    );
  end if;
end;
$$;

grant execute on function public.compute_daily_goal_completed(int, int, int) to authenticated;
grant execute on function public.bump_user_daily_stats(int, int, int) to authenticated;
grant execute on function public.fetch_user_daily_stats(int) to authenticated;
