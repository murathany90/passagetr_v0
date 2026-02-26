create or replace function public.apply_flashcard_result(p_word_id uuid, p_answer text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_delta int;
begin
  if v_user_id is null then
    raise exception 'unauthenticated';
  end if;

  if p_answer not in ('known','unsure','unknown') then
    raise exception 'invalid_answer';
  end if;

  v_delta := case
    when p_answer = 'known' then 12
    when p_answer = 'unsure' then 4
    else -8
  end;

  insert into public.user_word_progress (
    user_id, word_id, mastery, seen_count, correct_count, wrong_count, last_seen_at, last_answer
  )
  values (
    v_user_id,
    p_word_id,
    greatest(0, least(100, v_delta)),
    1, 0, 0, now(), p_answer
  )
  on conflict (user_id, word_id) do update
  set mastery = greatest(0, least(100, public.user_word_progress.mastery + v_delta)),
      seen_count = public.user_word_progress.seen_count + 1,
      last_seen_at = now(),
      last_answer = p_answer;
end;
$$;

create or replace function public.apply_test_result(p_word_id uuid, p_is_correct boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_delta int;
  v_answer text;
begin
  if v_user_id is null then
    raise exception 'unauthenticated';
  end if;

  v_delta := case when p_is_correct then 10 else -10 end;
  v_answer := case when p_is_correct then 'known' else 'unknown' end;

  insert into public.user_word_progress (
    user_id, word_id, mastery, seen_count, correct_count, wrong_count, last_seen_at, last_answer
  )
  values (
    v_user_id,
    p_word_id,
    greatest(0, least(100, v_delta)),
    1,
    case when p_is_correct then 1 else 0 end,
    case when p_is_correct then 0 else 1 end,
    now(),
    v_answer
  )
  on conflict (user_id, word_id) do update
  set mastery = greatest(0, least(100, public.user_word_progress.mastery + v_delta)),
      seen_count = public.user_word_progress.seen_count + 1,
      correct_count = public.user_word_progress.correct_count + case when p_is_correct then 1 else 0 end,
      wrong_count = public.user_word_progress.wrong_count + case when p_is_correct then 0 else 1 end,
      last_seen_at = now(),
      last_answer = v_answer;
end;
$$;

revoke all on function public.apply_flashcard_result(uuid, text) from public;
revoke all on function public.apply_test_result(uuid, boolean) from public;
grant execute on function public.apply_flashcard_result(uuid, text) to authenticated;
grant execute on function public.apply_test_result(uuid, boolean) to authenticated;
