create table if not exists public.ai_cover_model_daily_usage (
  usage_date_utc date not null,
  provider text not null,
  model text not null,
  attempt_count integer not null default 0,
  success_count integer not null default 0,
  failed_count integer not null default 0,
  rate_limited_count integer not null default 0,
  last_attempt_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (usage_date_utc, provider, model),
  constraint ai_cover_model_daily_usage_provider_check check (
    provider in ('imagerouter', 'huggingface')
  )
);

create or replace function public.admin_default_ai_cover_settings()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'local_caps_enabled', true,
    'models', jsonb_build_array(
      jsonb_build_object(
        'provider', 'imagerouter',
        'model_id', 'google/nano-banana-2:free',
        'enabled', true,
        'daily_cap', 3,
        'lifetime_cap', null,
        'priority', 1
      ),
      jsonb_build_object(
        'provider', 'imagerouter',
        'model_id', 'openai/gpt-image-1.5:free',
        'enabled', true,
        'daily_cap', 3,
        'lifetime_cap', 500,
        'priority', 2
      ),
      jsonb_build_object(
        'provider', 'imagerouter',
        'model_id', 'black-forest-labs/FLUX-2-klein-4b:free',
        'enabled', true,
        'daily_cap', 3,
        'lifetime_cap', null,
        'priority', 3
      ),
      jsonb_build_object(
        'provider', 'imagerouter',
        'model_id', 'z-image/turbo:free',
        'enabled', true,
        'daily_cap', 3,
        'lifetime_cap', null,
        'priority', 4
      ),
      jsonb_build_object(
        'provider', 'imagerouter',
        'model_id', 'qwen/qwen-image:free',
        'enabled', true,
        'daily_cap', 3,
        'lifetime_cap', null,
        'priority', 5
      ),
      jsonb_build_object(
        'provider', 'imagerouter',
        'model_id', 'google/gemini-2.5-flash:free',
        'enabled', true,
        'daily_cap', 3,
        'lifetime_cap', null,
        'priority', 6
      ),
      jsonb_build_object(
        'provider', 'huggingface',
        'model_id', 'stabilityai/stable-diffusion-xl-base-1.0',
        'enabled', true,
        'daily_cap', 50,
        'lifetime_cap', null,
        'priority', 7
      ),
      jsonb_build_object(
        'provider', 'huggingface',
        'model_id', 'black-forest-labs/FLUX.1-dev',
        'enabled', true,
        'daily_cap', 50,
        'lifetime_cap', null,
        'priority', 8
      ),
      jsonb_build_object(
        'provider', 'huggingface',
        'model_id', 'stabilityai/stable-diffusion-3.5-large',
        'enabled', true,
        'daily_cap', 50,
        'lifetime_cap', null,
        'priority', 9
      ),
      jsonb_build_object(
        'provider', 'huggingface',
        'model_id', 'playgroundai/playground-v2.5-1024px-aesthetic',
        'enabled', true,
        'daily_cap', 50,
        'lifetime_cap', null,
        'priority', 10
      )
    )
  );
$$;

create or replace function public.admin_normalize_ai_cover_settings(
  p_payload jsonb default null
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  with defaults as (
    select
      item,
      ord::integer as default_priority
    from jsonb_array_elements(
      public.admin_default_ai_cover_settings()->'models'
    ) with ordinality as source(item, ord)
  ),
  incoming as (
    select item
    from jsonb_array_elements(
      case
        when jsonb_typeof(coalesce(p_payload->'models', '[]'::jsonb)) = 'array'
          then coalesce(p_payload->'models', '[]'::jsonb)
        else '[]'::jsonb
      end
    ) as source(item)
  ),
  merged as (
    select
      defaults.item->>'provider' as provider,
      defaults.item->>'model_id' as model_id,
      coalesce((incoming.item->>'enabled')::boolean, (defaults.item->>'enabled')::boolean, true) as enabled,
      greatest(
        1,
        coalesce((incoming.item->>'daily_cap')::integer, (defaults.item->>'daily_cap')::integer, 1)
      ) as daily_cap,
      case
        when coalesce(incoming.item->>'lifetime_cap', defaults.item->>'lifetime_cap') is null then null
        else greatest(
          1,
          coalesce((incoming.item->>'lifetime_cap')::integer, (defaults.item->>'lifetime_cap')::integer, 1)
        )
      end as lifetime_cap,
      row_number() over (
        order by
          coalesce((incoming.item->>'priority')::integer, (defaults.item->>'priority')::integer, defaults.default_priority),
          defaults.default_priority
      )::integer as priority
    from defaults
    left join lateral (
      select incoming.item
      from incoming
      where incoming.item->>'provider' = defaults.item->>'provider'
        and incoming.item->>'model_id' = defaults.item->>'model_id'
      limit 1
    ) incoming on true
  )
  select jsonb_build_object(
    'local_caps_enabled',
      coalesce((p_payload->>'local_caps_enabled')::boolean, true),
    'models',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'provider', merged.provider,
              'model_id', merged.model_id,
              'enabled', merged.enabled,
              'daily_cap', merged.daily_cap,
              'lifetime_cap', merged.lifetime_cap,
              'priority', merged.priority
            )
            order by merged.priority
          )
          from merged
        ),
        '[]'::jsonb
      )
  );
$$;

create or replace function public.admin_default_settings()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'general', jsonb_build_object(
      'maintenance_mode', false,
      'maintenance_message', '',
      'support_email', ''
    ),
    'notifications', jsonb_build_object(
      'notify_on_bulk_user_updates', true,
      'notify_on_content_publish', true,
      'audit_digest_recipients', jsonb_build_array()
    ),
    'security', jsonb_build_object(
      'session_idle_timeout_minutes', 30,
      'invite_expiry_hours', 48,
      'reauth_required_for_role_changes', true
    ),
    'data_management', jsonb_build_object(
      'default_list_page_size', 50,
      'csv_import_duplicate_strategy', 'upsert',
      'default_publish_state_for_imports', true
    ),
    'ai_cover', public.admin_default_ai_cover_settings()
  );
$$;

create or replace function public.admin_normalize_settings(
  p_payload jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_general jsonb := coalesce(v_payload->'general', '{}'::jsonb);
  v_notifications jsonb := coalesce(v_payload->'notifications', '{}'::jsonb);
  v_security jsonb := coalesce(v_payload->'security', '{}'::jsonb);
  v_data jsonb := coalesce(v_payload->'data_management', '{}'::jsonb);
  v_duplicate_strategy text := lower(coalesce(v_data->>'csv_import_duplicate_strategy', 'upsert'));
begin
  if v_duplicate_strategy not in ('upsert', 'skip', 'error') then
    v_duplicate_strategy := 'upsert';
  end if;

  return jsonb_build_object(
    'general', jsonb_build_object(
      'maintenance_mode', coalesce((v_general->>'maintenance_mode')::boolean, false),
      'maintenance_message', coalesce(v_general->>'maintenance_message', ''),
      'support_email', coalesce(v_general->>'support_email', '')
    ),
    'notifications', jsonb_build_object(
      'notify_on_bulk_user_updates',
        coalesce((v_notifications->>'notify_on_bulk_user_updates')::boolean, true),
      'notify_on_content_publish',
        coalesce((v_notifications->>'notify_on_content_publish')::boolean, true),
      'audit_digest_recipients',
        case
          when jsonb_typeof(v_notifications->'audit_digest_recipients') = 'array'
            then v_notifications->'audit_digest_recipients'
          else jsonb_build_array()
        end
    ),
    'security', jsonb_build_object(
      'session_idle_timeout_minutes',
        greatest(5, least(240, coalesce((v_security->>'session_idle_timeout_minutes')::integer, 30))),
      'invite_expiry_hours',
        greatest(1, least(336, coalesce((v_security->>'invite_expiry_hours')::integer, 48))),
      'reauth_required_for_role_changes',
        coalesce((v_security->>'reauth_required_for_role_changes')::boolean, true)
    ),
    'data_management', jsonb_build_object(
      'default_list_page_size',
        greatest(10, least(100, coalesce((v_data->>'default_list_page_size')::integer, 50))),
      'csv_import_duplicate_strategy', v_duplicate_strategy,
      'default_publish_state_for_imports',
        coalesce((v_data->>'default_publish_state_for_imports')::boolean, true)
    ),
    'ai_cover', public.admin_normalize_ai_cover_settings(
      case
        when jsonb_typeof(v_payload->'ai_cover') = 'object'
          then v_payload->'ai_cover'
        else '{}'::jsonb
      end
    )
  );
end;
$$;

insert into public.app_settings (key, value)
values ('ai_cover', public.admin_default_ai_cover_settings())
on conflict (key) do nothing;

create or replace function public.admin_upsert_settings(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_normalized jsonb;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  v_normalized := public.admin_normalize_settings(p_payload);

  insert into public.app_settings (key, value, updated_by)
  values
    ('general', v_normalized->'general', auth.uid()),
    ('notifications', v_normalized->'notifications', auth.uid()),
    ('security', v_normalized->'security', auth.uid()),
    ('data_management', v_normalized->'data_management', auth.uid()),
    ('ai_cover', v_normalized->'ai_cover', auth.uid())
  on conflict (key) do update
    set value = excluded.value,
        updated_by = excluded.updated_by,
        updated_at = now();

  insert into public.audit_logs (
    actor_user_id,
    action,
    target_type,
    target_id,
    payload_json
  )
  values (
    auth.uid(),
    'admin.settings.updated',
    'app_settings',
    'global',
    v_normalized
  );

  return v_normalized;
end;
$$;

create or replace function public.admin_get_ai_cover_pool_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings jsonb := public.admin_get_settings();
  v_ai_cover jsonb := coalesce(v_settings->'ai_cover', '{}'::jsonb);
  v_usage_date date := (now() at time zone 'utc')::date;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  return (
    with configs as (
      select
        cfg.provider,
        cfg.model_id,
        cfg.enabled,
        cfg.daily_cap,
        cfg.lifetime_cap,
        cfg.priority
      from jsonb_to_recordset(
        coalesce(v_ai_cover->'models', '[]'::jsonb)
      ) as cfg(
        provider text,
        model_id text,
        enabled boolean,
        daily_cap integer,
        lifetime_cap integer,
        priority integer
      )
    )
    select jsonb_build_object(
      'usage_date_utc', v_usage_date::text,
      'local_caps_enabled', coalesce((v_ai_cover->>'local_caps_enabled')::boolean, true),
      'models', coalesce(
        jsonb_agg(
          jsonb_build_object(
            'provider', configs.provider,
            'model', configs.model_id,
            'enabled', configs.enabled,
            'priority', configs.priority,
            'daily_cap', configs.daily_cap,
            'lifetime_cap', configs.lifetime_cap,
            'attempt_count', coalesce(usage.attempt_count, 0),
            'success_count', coalesce(usage.success_count, 0),
            'failed_count', coalesce(usage.failed_count, 0),
            'rate_limited_count', coalesce(usage.rate_limited_count, 0)
          )
          order by case when configs.provider = 'imagerouter' then 0 else 1 end, configs.priority
        ),
        '[]'::jsonb
      )
    )
    from configs
    left join public.ai_cover_model_daily_usage usage
      on usage.usage_date_utc = v_usage_date
     and usage.provider = configs.provider
     and usage.model = configs.model_id
  );
end;
$$;

create or replace function public.admin_reserve_ai_cover_model_attempt(
  p_provider text,
  p_model text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_provider text := nullif(trim(coalesce(p_provider, '')), '');
  v_model text := nullif(trim(coalesce(p_model, '')), '');
  v_settings jsonb := public.admin_get_settings();
  v_ai_cover jsonb := coalesce(v_settings->'ai_cover', '{}'::jsonb);
  v_local_caps_enabled boolean := coalesce((v_ai_cover->>'local_caps_enabled')::boolean, true);
  v_enabled boolean := false;
  v_daily_cap integer := 0;
  v_lifetime_cap integer;
  v_usage_date date := (now() at time zone 'utc')::date;
  v_attempt_count integer := 0;
  v_lifetime_attempt_count integer := 0;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_provider is null or v_model is null then
    raise exception 'provider and model required';
  end if;

  select
    cfg.enabled,
    cfg.daily_cap,
    cfg.lifetime_cap
  into
    v_enabled,
    v_daily_cap,
    v_lifetime_cap
  from jsonb_to_recordset(
    coalesce(v_ai_cover->'models', '[]'::jsonb)
  ) as cfg(
    provider text,
    model_id text,
    enabled boolean,
    daily_cap integer,
    lifetime_cap integer,
    priority integer
  )
  where cfg.provider = v_provider
    and cfg.model_id = v_model
  limit 1;

  if not found then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'unknown_model'
    );
  end if;

  if not coalesce(v_enabled, false) then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'model_disabled',
      'daily_cap', v_daily_cap,
      'lifetime_cap', v_lifetime_cap
    );
  end if;

  select coalesce(attempt_count, 0)
  into v_attempt_count
  from public.ai_cover_model_daily_usage
  where usage_date_utc = v_usage_date
    and provider = v_provider
    and model = v_model;

  select coalesce(sum(attempt_count), 0)::integer
  into v_lifetime_attempt_count
  from public.ai_cover_model_daily_usage
  where provider = v_provider
    and model = v_model;

  if v_local_caps_enabled and v_daily_cap > 0 and v_attempt_count >= v_daily_cap then
    insert into public.ai_cover_model_daily_usage (
      usage_date_utc,
      provider,
      model,
      rate_limited_count,
      last_attempt_at,
      updated_at
    )
    values (
      v_usage_date,
      v_provider,
      v_model,
      1,
      now(),
      now()
    )
    on conflict (usage_date_utc, provider, model) do update
      set rate_limited_count = public.ai_cover_model_daily_usage.rate_limited_count + 1,
          last_attempt_at = now(),
          updated_at = now();

    return jsonb_build_object(
      'allowed', false,
      'reason', 'daily_cap_reached',
      'daily_cap', v_daily_cap,
      'lifetime_cap', v_lifetime_cap,
      'attempt_count', v_attempt_count
    );
  end if;

  if v_local_caps_enabled and v_lifetime_cap is not null and v_lifetime_attempt_count >= v_lifetime_cap then
    insert into public.ai_cover_model_daily_usage (
      usage_date_utc,
      provider,
      model,
      rate_limited_count,
      last_attempt_at,
      updated_at
    )
    values (
      v_usage_date,
      v_provider,
      v_model,
      1,
      now(),
      now()
    )
    on conflict (usage_date_utc, provider, model) do update
      set rate_limited_count = public.ai_cover_model_daily_usage.rate_limited_count + 1,
          last_attempt_at = now(),
          updated_at = now();

    return jsonb_build_object(
      'allowed', false,
      'reason', 'lifetime_cap_reached',
      'daily_cap', v_daily_cap,
      'lifetime_cap', v_lifetime_cap,
      'attempt_count', v_attempt_count
    );
  end if;

  insert into public.ai_cover_model_daily_usage (
    usage_date_utc,
    provider,
    model,
    attempt_count,
    last_attempt_at,
    updated_at
  )
  values (
    v_usage_date,
    v_provider,
    v_model,
    1,
    now(),
    now()
  )
  on conflict (usage_date_utc, provider, model) do update
    set attempt_count = public.ai_cover_model_daily_usage.attempt_count + 1,
        last_attempt_at = now(),
        updated_at = now()
  returning attempt_count into v_attempt_count;

  return jsonb_build_object(
    'allowed', true,
    'reason', null,
    'daily_cap', v_daily_cap,
    'lifetime_cap', v_lifetime_cap,
    'attempt_count', v_attempt_count
  );
end;
$$;

create or replace function public.admin_mark_ai_cover_model_attempt_result(
  p_provider text,
  p_model text,
  p_result text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_provider text := nullif(trim(coalesce(p_provider, '')), '');
  v_model text := nullif(trim(coalesce(p_model, '')), '');
  v_result text := nullif(trim(coalesce(p_result, '')), '');
  v_usage_date date := (now() at time zone 'utc')::date;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_provider is null or v_model is null or v_result is null then
    raise exception 'provider, model and result required';
  end if;

  if v_result not in ('success', 'failed', 'rate_limited') then
    raise exception 'result invalid';
  end if;

  insert into public.ai_cover_model_daily_usage (
    usage_date_utc,
    provider,
    model,
    success_count,
    failed_count,
    rate_limited_count,
    updated_at
  )
  values (
    v_usage_date,
    v_provider,
    v_model,
    case when v_result = 'success' then 1 else 0 end,
    case when v_result = 'failed' then 1 else 0 end,
    case when v_result = 'rate_limited' then 1 else 0 end,
    now()
  )
  on conflict (usage_date_utc, provider, model) do update
    set success_count = public.ai_cover_model_daily_usage.success_count +
        case when v_result = 'success' then 1 else 0 end,
        failed_count = public.ai_cover_model_daily_usage.failed_count +
        case when v_result = 'failed' then 1 else 0 end,
        rate_limited_count = public.ai_cover_model_daily_usage.rate_limited_count +
        case when v_result = 'rate_limited' then 1 else 0 end,
        updated_at = now();

  return jsonb_build_object('ok', true);
end;
$$;

update public.reading_ai_runs
set status = 'paused',
    provider = 'cover_auto',
    model = 'auto',
    pause_reason = 'provider_migration_required',
    consecutive_failure_count = 0,
    updated_at = now()
where job_type = 'cover_backfill'
  and status in ('queued', 'running', 'paused')
  and provider in ('gemini_image', 'openai_images');

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
    v_provider := coalesce(v_provider, 'cover_auto');
    v_model := coalesce(v_model, 'auto');
    if v_provider not in ('cover_auto', 'imagerouter', 'huggingface') then
      raise exception 'cover provider invalid';
    end if;
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
      v_provider := coalesce(v_provider, v_run.provider, 'cover_auto');
      v_model := coalesce(v_model, v_run.model, 'auto');
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
    v_provider := coalesce(v_provider, v_run.provider, 'cover_auto');
    v_model := coalesce(v_model, v_run.model, 'auto');
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

grant select on table public.ai_cover_model_daily_usage to authenticated;
grant execute on function public.admin_get_ai_cover_pool_status() to authenticated;
grant execute on function public.admin_reserve_ai_cover_model_attempt(text, text) to authenticated;
grant execute on function public.admin_mark_ai_cover_model_attempt_result(text, text, text) to authenticated;
