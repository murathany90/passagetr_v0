alter table public.reading_ai_runs
  add column if not exists pause_reason text,
  add column if not exists last_error_message text,
  add column if not exists consecutive_failure_count integer not null default 0;

alter table public.reading_ai_runs
  drop constraint if exists reading_ai_runs_status_check;

alter table public.reading_ai_runs
  add constraint reading_ai_runs_status_check check (
    status in ('queued', 'running', 'paused', 'completed', 'failed', 'cancelled')
  );

create or replace function public.admin_create_reading_ai_run(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_run_id uuid := gen_random_uuid();
  v_job_type text := nullif(trim(coalesce(p_payload->>'job_type', '')), '');
  v_provider text := nullif(trim(coalesce(p_payload->>'provider', '')), '');
  v_model text := nullif(trim(coalesce(p_payload->>'model', '')), '');
  v_question_count integer := greatest(coalesce((p_payload->>'question_count')::integer, 3), 1);
  v_filter_snapshot jsonb := case
    when jsonb_typeof(p_payload->'filter_snapshot') = 'object' then p_payload->'filter_snapshot'
    else '{}'::jsonb
  end;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_job_type not in ('question_backfill', 'cover_backfill') then
    raise exception 'job_type invalid';
  end if;

  if jsonb_typeof(p_payload->'reading_ids') <> 'array' then
    raise exception 'reading_ids array required';
  end if;

  if v_job_type = 'cover_backfill' then
    v_model := coalesce(v_model, 'gemini-2.5-flash-image');
    v_provider := case
      when v_model = 'gpt-image-1.5' then 'openai_images'
      else 'gemini_image'
    end;
  else
    v_provider := coalesce(v_provider, 'gemini');
    v_model := coalesce(
      v_model,
      case
        when v_provider = 'openrouter' then 'arcee-ai/trinity-large-preview:free'
        else 'gemini-2.5-flash'
      end
    );
  end if;

  insert into public.reading_ai_runs (
    id,
    job_type,
    status,
    provider,
    model,
    question_count,
    filter_snapshot,
    created_by,
    updated_by
  )
  values (
    v_run_id,
    v_job_type,
    'queued',
    v_provider,
    v_model,
    v_question_count,
    v_filter_snapshot,
    auth.uid(),
    auth.uid()
  );

  insert into public.reading_ai_run_items (
    run_id,
    passage_id
  )
  select
    v_run_id,
    rp.id
  from public.reading_passages rp
  where rp.id in (
    select distinct nullif(trim(value::text, '"'), '')::uuid
    from jsonb_array_elements(p_payload->'reading_ids')
  );

  return public.admin_get_reading_ai_run(v_run_id);
end;
$$;

create or replace function public.admin_recalculate_reading_ai_run(
  p_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_run public.reading_ai_runs%rowtype;
  v_total_count integer := 0;
  v_processed_count integer := 0;
  v_succeeded_count integer := 0;
  v_failed_count integer := 0;
  v_skipped_count integer := 0;
  v_has_processing boolean := false;
  v_has_queued boolean := false;
  v_status text := 'queued';
  v_failure_samples jsonb := '[]'::jsonb;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select *
  into v_run
  from public.reading_ai_runs
  where id = p_run_id;

  if v_run.id is null then
    raise exception 'reading ai run not found';
  end if;

  select
    count(*)::integer,
    count(*) filter (where item.status in ('succeeded', 'failed', 'skipped'))::integer,
    count(*) filter (where item.status = 'succeeded')::integer,
    count(*) filter (where item.status = 'failed')::integer,
    count(*) filter (where item.status = 'skipped')::integer,
    bool_or(item.status = 'processing'),
    bool_or(item.status = 'queued')
  into
    v_total_count,
    v_processed_count,
    v_succeeded_count,
    v_failed_count,
    v_skipped_count,
    v_has_processing,
    v_has_queued
  from public.reading_ai_run_items item
  where item.run_id = p_run_id;

  select coalesce(
    jsonb_agg(sample.message order by sample.message),
    '[]'::jsonb
  )
  into v_failure_samples
  from (
    select concat(
      coalesce(rp.title, item.passage_id::text),
      ': ',
      left(coalesce(item.error_message, 'Bilinmeyen hata'), 180)
    ) as message
    from public.reading_ai_run_items item
    join public.reading_passages rp
      on rp.id = item.passage_id
    where item.run_id = p_run_id
      and item.status = 'failed'
    order by item.updated_at desc
    limit 5
  ) sample;

  if v_total_count = 0 or v_processed_count >= v_total_count then
    v_status := case
      when v_run.status = 'cancelled' then 'cancelled'
      else 'completed'
    end;
  elsif v_run.status = 'cancelled' then
    v_status := 'cancelled';
  elsif v_run.status = 'paused' then
    v_status := 'paused';
  elsif v_has_processing or v_run.started_at is not null then
    v_status := 'running';
  elsif v_has_queued then
    v_status := 'queued';
  else
    v_status := v_run.status;
  end if;

  update public.reading_ai_runs
  set status = v_status,
      total_count = v_total_count,
      processed_count = v_processed_count,
      succeeded_count = v_succeeded_count,
      failed_count = v_failed_count,
      skipped_count = v_skipped_count,
      started_at = case
        when started_at is not null then started_at
        when v_has_processing or v_processed_count > 0 then now()
        else started_at
      end,
      completed_at = case
        when v_status in ('completed', 'cancelled') then coalesce(completed_at, now())
        else null
      end,
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_run_id
  returning * into v_run;

  return jsonb_build_object(
    'id', v_run.id::text,
    'job_type', v_run.job_type,
    'status', v_run.status,
    'provider', v_run.provider,
    'model', v_run.model,
    'question_count', v_run.question_count,
    'filter_snapshot', v_run.filter_snapshot,
    'total_count', v_run.total_count,
    'processed_count', v_run.processed_count,
    'succeeded_count', v_run.succeeded_count,
    'failed_count', v_run.failed_count,
    'skipped_count', v_run.skipped_count,
    'failure_samples', v_failure_samples,
    'pause_reason', v_run.pause_reason,
    'last_error_message', v_run.last_error_message,
    'consecutive_failure_count', v_run.consecutive_failure_count,
    'started_at', v_run.started_at,
    'completed_at', v_run.completed_at,
    'updated_at', v_run.updated_at
  );
end;
$$;

create or replace function public.admin_get_reading_ai_run(
  p_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  return public.admin_recalculate_reading_ai_run(p_run_id);
end;
$$;

create or replace function public.admin_list_active_reading_ai_runs()
returns table (
  id uuid,
  job_type text,
  status text,
  provider text,
  model text,
  question_count integer,
  filter_snapshot jsonb,
  total_count integer,
  processed_count integer,
  succeeded_count integer,
  failed_count integer,
  skipped_count integer,
  failure_samples jsonb,
  pause_reason text,
  last_error_message text,
  consecutive_failure_count integer,
  started_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public, auth
as $$
  select
    (summary->>'id')::uuid as id,
    summary->>'job_type' as job_type,
    summary->>'status' as status,
    summary->>'provider' as provider,
    summary->>'model' as model,
    coalesce((summary->>'question_count')::integer, 0) as question_count,
    coalesce(summary->'filter_snapshot', '{}'::jsonb) as filter_snapshot,
    coalesce((summary->>'total_count')::integer, 0) as total_count,
    coalesce((summary->>'processed_count')::integer, 0) as processed_count,
    coalesce((summary->>'succeeded_count')::integer, 0) as succeeded_count,
    coalesce((summary->>'failed_count')::integer, 0) as failed_count,
    coalesce((summary->>'skipped_count')::integer, 0) as skipped_count,
    coalesce(summary->'failure_samples', '[]'::jsonb) as failure_samples,
    nullif(summary->>'pause_reason', '') as pause_reason,
    nullif(summary->>'last_error_message', '') as last_error_message,
    coalesce((summary->>'consecutive_failure_count')::integer, 0) as consecutive_failure_count,
    nullif(summary->>'started_at', '')::timestamptz as started_at,
    nullif(summary->>'completed_at', '')::timestamptz as completed_at,
    nullif(summary->>'updated_at', '')::timestamptz as updated_at
  from (
    select public.admin_get_reading_ai_run(run.id) as summary
    from public.reading_ai_runs run
    where run.status in ('queued', 'running', 'paused')
    order by run.updated_at desc
  ) active_runs;
$$;

create or replace function public.admin_claim_reading_ai_run_items(
  p_run_id uuid,
  p_limit integer default 3
)
returns table (
  item_id uuid,
  passage_id uuid,
  passage_title text
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_run_status text;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select status
  into v_run_status
  from public.reading_ai_runs
  where id = p_run_id
  for update;

  if v_run_status is null then
    raise exception 'reading ai run not found';
  end if;

  if v_run_status in ('paused', 'cancelled', 'completed', 'failed') then
    return;
  end if;

  update public.reading_ai_runs
  set status = 'running',
      started_at = coalesce(started_at, now()),
      updated_at = now(),
      updated_by = auth.uid()
  where id = p_run_id;

  return query
  with claim as (
    select item.id
    from public.reading_ai_run_items item
    where item.run_id = p_run_id
      and item.status = 'queued'
    order by item.created_at asc
    limit greatest(1, least(coalesce(p_limit, 3), 20))
    for update skip locked
  ),
  updated as (
    update public.reading_ai_run_items item
    set status = 'processing',
        started_at = coalesce(item.started_at, now()),
        updated_at = now(),
        attempt_count = item.attempt_count + 1
    from claim
    where item.id = claim.id
    returning item.id, item.passage_id
  )
  select
    updated.id,
    updated.passage_id,
    coalesce(rp.title, '')
  from updated
  join public.reading_passages rp
    on rp.id = updated.passage_id;
end;
$$;

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

  if v_status = 'failed' then
    v_next_consecutive_failure_count := coalesce(v_run.consecutive_failure_count, 0) + 1;
    update public.reading_ai_runs
    set consecutive_failure_count = v_next_consecutive_failure_count,
        last_error_message = v_error_message,
        pause_reason = case
          when v_next_consecutive_failure_count >= 5 and status = 'running' then 'auto_failure_threshold'
          else pause_reason
        end,
        status = case
          when v_next_consecutive_failure_count >= 5 and status = 'running' then 'paused'
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

grant execute on function public.admin_get_reading_ai_run(uuid) to authenticated;
grant execute on function public.admin_list_active_reading_ai_runs() to authenticated;
grant execute on function public.admin_claim_reading_ai_run_items(uuid, integer) to authenticated;
grant execute on function public.admin_mark_reading_ai_run_item(jsonb) to authenticated;
grant execute on function public.admin_control_reading_ai_run(jsonb) to authenticated;
