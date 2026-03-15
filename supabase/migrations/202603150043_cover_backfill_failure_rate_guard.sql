create or replace function public.admin_mark_reading_ai_run_item(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_item_id uuid := nullif(trim(coalesce(p_payload->>'item_id', '')), '')::uuid;
  v_status text := nullif(trim(coalesce(p_payload->>'status', '')), '');
  v_error_message text := nullif(trim(coalesce(p_payload->>'error_message', '')), '');
  v_run_id uuid;
  v_run public.reading_ai_runs%rowtype;
  v_next_consecutive_failure_count integer := 0;
  v_processed_count integer := 0;
  v_failed_count integer := 0;
  v_pause_reason text := null;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_item_id is null then
    raise exception 'item_id required';
  end if;

  if v_status not in ('succeeded', 'failed', 'skipped') then
    raise exception 'status invalid';
  end if;

  update public.reading_ai_run_items
  set status = v_status,
      error_message = v_error_message,
      completed_at = now(),
      updated_at = now()
  where id = v_item_id
  returning run_id into v_run_id;

  if v_run_id is null then
    raise exception 'reading ai run item not found';
  end if;

  select *
  into v_run
  from public.reading_ai_runs
  where id = v_run_id
  for update;

  select
    count(*) filter (where status in ('succeeded', 'failed', 'skipped'))::integer,
    count(*) filter (where status = 'failed')::integer
  into v_processed_count, v_failed_count
  from public.reading_ai_run_items
  where run_id = v_run_id;

  if v_status = 'failed' then
    v_next_consecutive_failure_count := coalesce(v_run.consecutive_failure_count, 0) + 1;
    if v_next_consecutive_failure_count >= 5 and v_run.status = 'running' then
      v_pause_reason := 'auto_failure_threshold';
    elsif v_processed_count >= 10 and (v_failed_count * 100) >= (v_processed_count * 60) and v_run.status = 'running' then
      v_pause_reason := 'auto_failure_rate_threshold';
    end if;

    update public.reading_ai_runs
    set consecutive_failure_count = v_next_consecutive_failure_count,
        last_error_message = v_error_message,
        pause_reason = coalesce(v_pause_reason, pause_reason),
        status = case
          when v_pause_reason is not null then 'paused'
          else status
        end,
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_run_id;
  else
    update public.reading_ai_runs
    set consecutive_failure_count = 0,
        last_error_message = null,
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_run_id;
  end if;

  return public.admin_recalculate_reading_ai_run(v_run_id);
end;
$$;

create or replace function public.admin_control_reading_ai_run(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_run_id uuid := nullif(trim(coalesce(p_payload->>'run_id', '')), '')::uuid;
  v_action text := nullif(trim(coalesce(p_payload->>'action', '')), '');
  v_provider text := nullif(trim(coalesce(p_payload->>'provider', '')), '');
  v_model text := nullif(trim(coalesce(p_payload->>'model', '')), '');
  v_question_count integer := greatest(coalesce((p_payload->>'question_count')::integer, 0), 0);
  v_run public.reading_ai_runs%rowtype;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_run_id is null then
    raise exception 'run_id required';
  end if;

  if v_action not in ('pause', 'resume', 'cancel', 'update_config') then
    raise exception 'action invalid';
  end if;

  select *
  into v_run
  from public.reading_ai_runs
  where id = v_run_id
  for update;

  if v_run.id is null then
    raise exception 'reading ai run not found';
  end if;

  if v_action = 'pause' then
    if v_run.status in ('queued', 'running') then
      update public.reading_ai_runs
      set status = 'paused',
          pause_reason = 'user_paused',
          updated_at = now(),
          updated_by = auth.uid()
      where id = v_run_id;
    end if;
    return public.admin_get_reading_ai_run(v_run_id);
  end if;

  if v_action = 'resume' then
    if v_run.status not in ('queued', 'paused') then
      raise exception 'run cannot be resumed';
    end if;

    if v_run.job_type = 'cover_backfill' then
      v_model := coalesce(v_model, v_run.model, 'gemini-2.5-flash-image');
      v_provider := case
        when v_model = 'gpt-image-1.5' then 'openai_images'
        else 'gemini_image'
      end;
    else
      v_provider := coalesce(v_provider, v_run.provider, 'gemini');
      v_model := coalesce(v_model, v_run.model);
    end if;

    update public.reading_ai_runs
    set status = 'queued',
        provider = coalesce(v_provider, provider),
        model = coalesce(v_model, model),
        pause_reason = null,
        last_error_message = null,
        consecutive_failure_count = 0,
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_run_id;

    return public.admin_get_reading_ai_run(v_run_id);
  end if;

  if v_action = 'cancel' then
    if v_run.status in ('completed', 'failed', 'cancelled') then
      return public.admin_get_reading_ai_run(v_run_id);
    end if;

    update public.reading_ai_runs
    set status = 'cancelled',
        pause_reason = 'user_cancelled',
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_run_id;

    return public.admin_get_reading_ai_run(v_run_id);
  end if;

  if v_run.status not in ('queued', 'paused') then
    raise exception 'run config can only be updated while queued or paused';
  end if;

  if v_run.job_type = 'cover_backfill' then
    v_model := coalesce(v_model, v_run.model, 'gemini-2.5-flash-image');
    v_provider := case
      when v_model = 'gpt-image-1.5' then 'openai_images'
      else 'gemini_image'
    end;
  else
    v_provider := coalesce(v_provider, v_run.provider, 'gemini');
    v_model := coalesce(v_model, v_run.model);
  end if;

  update public.reading_ai_runs
  set provider = coalesce(v_provider, provider),
      model = coalesce(v_model, model),
      question_count = case
        when v_question_count > 0 then v_question_count
        else question_count
      end,
      updated_at = now(),
      updated_by = auth.uid()
  where id = v_run_id;

  return public.admin_get_reading_ai_run(v_run_id);
end;
$$;
