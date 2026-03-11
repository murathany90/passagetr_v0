alter table public.packs
  add column if not exists publish_at timestamptz,
  add column if not exists unpublish_at timestamptz;

alter table public.words
  add column if not exists publish_at timestamptz,
  add column if not exists unpublish_at timestamptz;

alter table public.reading_passages
  add column if not exists publish_at timestamptz,
  add column if not exists unpublish_at timestamptz;

alter table public.gramer_modulleri
  add column if not exists publish_at timestamptz,
  add column if not exists unpublish_at timestamptz;

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

drop trigger if exists trg_app_settings_updated_at on public.app_settings;
create trigger trg_app_settings_updated_at
before update on public.app_settings
for each row execute function public.set_updated_at();

grant select on public.app_settings to authenticated;

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
    )
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
    )
  );
end;
$$;

insert into public.app_settings (key, value)
values
  ('general', public.admin_default_settings()->'general'),
  ('notifications', public.admin_default_settings()->'notifications'),
  ('security', public.admin_default_settings()->'security'),
  ('data_management', public.admin_default_settings()->'data_management')
on conflict (key) do nothing;

create or replace function public.admin_get_settings()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payload jsonb;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  into v_payload
  from public.app_settings;

  return public.admin_normalize_settings(v_payload);
end;
$$;

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
    ('data_management', v_normalized->'data_management', auth.uid())
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

create or replace function public.admin_apply_user_access(
  p_user_id uuid,
  p_role text,
  p_plan text,
  p_actor_user_id uuid default auth.uid(),
  p_audit_action text default 'admin.user_access.updated'
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_now timestamptz := now();
  v_role text := lower(coalesce(p_role, 'user'));
  v_plan text := lower(coalesce(p_plan, 'free'));
  v_request_role text := coalesce(auth.jwt()->>'role', '');
begin
  if v_request_role <> 'service_role' and not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if v_role not in ('user', 'admin', 'developer') then
    raise exception 'invalid role';
  end if;

  if v_plan not in ('free', 'pro') then
    raise exception 'invalid plan';
  end if;

  if v_role = 'developer'
     and v_request_role <> 'service_role'
     and not public.is_developer() then
    raise exception 'developer role may only be granted by developer';
  end if;

  insert into public.user_roles (
    user_id,
    role,
    granted_at,
    granted_by,
    revoked_at
  )
  values (
    p_user_id,
    'user',
    v_now,
    p_actor_user_id,
    null
  )
  on conflict (user_id, role) do update
    set revoked_at = null,
        granted_at = excluded.granted_at,
        granted_by = excluded.granted_by;

  update public.user_roles
  set revoked_at = v_now
  where user_id = p_user_id
    and revoked_at is null
    and role in ('admin', 'developer')
    and role <> v_role;

  if v_role in ('admin', 'developer') then
    insert into public.user_roles (
      user_id,
      role,
      granted_at,
      granted_by,
      revoked_at
    )
    values (
      p_user_id,
      v_role,
      v_now,
      p_actor_user_id,
      null
    )
    on conflict (user_id, role) do update
      set revoked_at = null,
          granted_at = excluded.granted_at,
          granted_by = excluded.granted_by;
  end if;

  update public.entitlements
  set revoked_at = v_now
  where user_id = p_user_id
    and revoked_at is null
    and plan <> v_plan;

  if not exists (
    select 1
    from public.entitlements e
    where e.user_id = p_user_id
      and e.plan = v_plan
      and e.revoked_at is null
      and e.starts_at <= v_now
      and (e.expires_at is null or e.expires_at > v_now)
  ) then
    insert into public.entitlements (
      user_id,
      plan,
      starts_at,
      source,
      granted_by
    )
    values (
      p_user_id,
      v_plan,
      v_now,
      'admin_console',
      p_actor_user_id
    );
  end if;

  insert into public.audit_logs (
    actor_user_id,
    action,
    target_type,
    target_id,
    payload_json
  )
  values (
    p_actor_user_id,
    p_audit_action,
    'profiles',
    p_user_id::text,
    jsonb_build_object('role', v_role, 'plan', v_plan)
  );
end;
$$;

create or replace function public.admin_set_user_access(
  p_user_id uuid,
  p_role text,
  p_plan text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  perform public.admin_apply_user_access(
    p_user_id,
    p_role,
    p_plan,
    auth.uid(),
    'admin.user_access.updated'
  );
end;
$$;

create or replace function public.admin_bulk_set_user_access(
  p_user_ids uuid[],
  p_role text default null,
  p_plan text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
  v_effective_role text;
  v_effective_plan text;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if p_user_ids is null or cardinality(p_user_ids) = 0 then
    raise exception 'at least one user id is required';
  end if;

  if p_role is null and p_plan is null then
    raise exception 'role or plan must be provided';
  end if;

  foreach v_user_id in array p_user_ids
  loop
    select
      coalesce(
        (
          select ur.role
          from public.user_roles ur
          where ur.user_id = v_user_id
            and ur.revoked_at is null
          order by case ur.role
            when 'developer' then 3
            when 'admin' then 2
            else 1
          end desc
          limit 1
        ),
        'user'
      ),
      coalesce(
        (
          select e.plan
          from public.entitlements e
          where e.user_id = v_user_id
            and e.revoked_at is null
            and e.starts_at <= now()
            and (e.expires_at is null or e.expires_at > now())
          order by e.starts_at desc
          limit 1
        ),
        'free'
      )
    into v_effective_role, v_effective_plan;

    perform public.admin_apply_user_access(
      v_user_id,
      coalesce(lower(p_role), v_effective_role),
      coalesce(lower(p_plan), v_effective_plan),
      auth.uid(),
      'admin.user_access.bulk_updated'
    );
  end loop;
end;
$$;

create or replace function public.admin_assign_invited_user_access(
  p_user_id uuid,
  p_role text,
  p_plan text,
  p_actor_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'service_role required';
  end if;

  perform public.admin_apply_user_access(
    p_user_id,
    p_role,
    p_plan,
    p_actor_user_id,
    'admin.user_invited'
  );
end;
$$;

drop function if exists public.admin_list_packs();

create or replace function public.admin_list_users_paged(
  p_query text default null,
  p_role text default null,
  p_plan text default null,
  p_status text default null,
  p_offset integer default 0,
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_items jsonb;
  v_total integer;
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_query text := nullif(trim(coalesce(p_query, '')), '');
  v_role text := nullif(lower(trim(coalesce(p_role, ''))), '');
  v_plan text := nullif(lower(trim(coalesce(p_plan, ''))), '');
  v_status text := nullif(lower(trim(coalesce(p_status, ''))), '');
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  with raw_users as (
    select
      u.id as user_id,
      coalesce(u.email, '') as email,
      coalesce(p.display_name, '') as display_name,
      coalesce(
        (
          select ur.role
          from public.user_roles ur
          where ur.user_id = u.id
            and ur.revoked_at is null
          order by case ur.role
            when 'developer' then 3
            when 'admin' then 2
            else 1
          end desc
          limit 1
        ),
        'user'
      ) as app_role,
      coalesce(
        (
          select e.plan
          from public.entitlements e
          where e.user_id = u.id
            and e.revoked_at is null
            and e.starts_at <= now()
            and (e.expires_at is null or e.expires_at > now())
          order by e.starts_at desc
          limit 1
        ),
        'free'
      ) as plan,
      case
        when coalesce(p.is_anonymous, false) then 'anonymous'
        when exists (
          select 1
          from public.user_roles ur
          where ur.user_id = u.id
            and ur.revoked_at is null
            and ur.role in ('admin', 'developer')
        ) then 'staff'
        else 'active'
      end as status_label,
      u.last_sign_in_at as last_seen_at,
      coalesce(p.updated_at, u.created_at) as updated_at,
      u.created_at
    from auth.users u
    left join public.profiles p
      on p.user_id = u.id
  ),
  filtered as (
    select *
    from raw_users
    where (v_query is null or email ilike '%' || v_query || '%' or display_name ilike '%' || v_query || '%')
      and (v_role is null or app_role = v_role)
      and (v_plan is null or plan = v_plan)
      and (v_status is null or v_status = 'all' or status_label = v_status)
  ),
  paged as (
    select *
    from filtered
    order by coalesce(last_seen_at, created_at) desc, email asc
    offset v_offset
    limit v_limit
  )
  select count(*)::integer into v_total
  from filtered;

  select coalesce(jsonb_agg(to_jsonb(paged)), '[]'::jsonb)
  into v_items
  from paged;

  return jsonb_build_object(
    'items', v_items,
    'total_count', v_total,
    'offset', v_offset,
    'limit', v_limit
  );
end;
$$;

create or replace function public.admin_list_packs()
returns table (
  id text,
  name text,
  word_count integer,
  is_published boolean,
  created_at timestamptz,
  updated_at timestamptz,
  updated_by_email text
)
language sql
security definer
set search_path = public, auth
as $$
  select
    p.id::text,
    coalesce(p.name, ''),
    (
      select count(*)::integer
      from public.words w
      where w.pack_id = p.id
    ) as word_count,
    coalesce(p.is_published, false),
    p.created_at,
    p.updated_at,
    coalesce(actor.email, '')
  from public.packs p
  left join auth.users actor
    on actor.id = p.updated_by
  where public.is_admin_or_developer()
  order by p.name asc;
$$;

create or replace function public.admin_list_words_paged(
  p_pack_id uuid default null,
  p_query text default null,
  p_status text default null,
  p_offset integer default 0,
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_items jsonb;
  v_total integer;
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_query text := nullif(trim(coalesce(p_query, '')), '');
  v_status text := nullif(lower(trim(coalesce(p_status, ''))), '');
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  with filtered as (
    select
      w.id::text as id,
      w.pack_id::text as pack_id,
      coalesce(w.en_word, '') as en_word,
      coalesce(w.tr_meaning, '') as tr_meaning,
      coalesce(w.pos, '') as pos,
      coalesce(w.example_en, '') as example_en,
      w.example_tr,
      w.level,
      w.notes,
      coalesce(w.is_published, false) as is_published,
      w.created_at,
      w.updated_at,
      coalesce(actor.email, '') as updated_by_email
    from public.words w
    left join auth.users actor
      on actor.id = w.updated_by
    where (p_pack_id is null or w.pack_id = p_pack_id)
      and (
        v_query is null
        or concat_ws(' ', w.en_word, w.tr_meaning, w.pos, coalesce(w.level, ''), coalesce(w.notes, ''))
           ilike '%' || v_query || '%'
      )
      and (
        v_status is null
        or v_status = 'all'
        or (v_status = 'published' and coalesce(w.is_published, false))
        or (v_status = 'draft' and not coalesce(w.is_published, false))
      )
  ),
  paged as (
    select *
    from filtered
    order by en_word asc
    offset v_offset
    limit v_limit
  )
  select count(*)::integer into v_total
  from filtered;

  select coalesce(jsonb_agg(to_jsonb(paged)), '[]'::jsonb)
  into v_items
  from paged;

  return jsonb_build_object(
    'items', v_items,
    'total_count', v_total,
    'offset', v_offset,
    'limit', v_limit
  );
end;
$$;

create or replace function public.admin_list_reading_passages_paged(
  p_query text default null,
  p_level text default null,
  p_status text default null,
  p_offset integer default 0,
  p_limit integer default 50
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_items jsonb;
  v_total integer;
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_query text := nullif(trim(coalesce(p_query, '')), '');
  v_level text := nullif(trim(coalesce(p_level, '')), '');
  v_status text := nullif(lower(trim(coalesce(p_status, ''))), '');
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  with filtered as (
    select
      rp.id::text as id,
      rp.pack_id::text as pack_id,
      rp.pack_name,
      coalesce(rp.title, '') as title,
      rp.level,
      rp.category,
      rp.tags_raw,
      coalesce(rp.is_pro, false) as is_pro,
      coalesce(rp.is_published, false) as is_published,
      rp.created_at,
      rp.updated_at,
      coalesce(actor.email, '') as updated_by_email
    from public.reading_passages rp
    left join auth.users actor
      on actor.id = rp.updated_by
    where (
        v_query is null
        or concat_ws(' ', rp.title, coalesce(rp.category, ''), coalesce(rp.level, ''), coalesce(rp.tags_raw, ''))
           ilike '%' || v_query || '%'
      )
      and (v_level is null or rp.level = v_level)
      and (
        v_status is null
        or v_status = 'all'
        or (v_status = 'published' and coalesce(rp.is_published, false))
        or (v_status = 'draft' and not coalesce(rp.is_published, false))
      )
  ),
  paged as (
    select *
    from filtered
    order by title asc
    offset v_offset
    limit v_limit
  )
  select count(*)::integer into v_total
  from filtered;

  select coalesce(jsonb_agg(to_jsonb(paged)), '[]'::jsonb)
  into v_items
  from paged;

  return jsonb_build_object(
    'items', v_items,
    'total_count', v_total,
    'offset', v_offset,
    'limit', v_limit
  );
end;
$$;

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
  v_total_words integer;
  v_current_words integer;
  v_previous_words integer;
  v_total_readings integer;
  v_current_readings integer;
  v_previous_readings integer;
  v_total_grammar integer;
  v_current_grammar integer;
  v_previous_grammar integer;
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

  select count(*)::integer into v_total_words from public.words;
  select count(*)::integer into v_current_words from public.words where created_at >= v_current_start;
  select count(*)::integer into v_previous_words from public.words where created_at >= v_previous_start and created_at < v_current_start;

  select count(*)::integer into v_total_readings from public.reading_passages;
  select count(*)::integer into v_current_readings from public.reading_passages where created_at >= v_current_start;
  select count(*)::integer into v_previous_readings from public.reading_passages where created_at >= v_previous_start and created_at < v_current_start;

  select count(*)::integer into v_total_grammar from public.gramer_modulleri;
  select count(*)::integer into v_current_grammar from public.gramer_modulleri where created_at >= v_current_start;
  select count(*)::integer into v_previous_grammar from public.gramer_modulleri where created_at >= v_previous_start and created_at < v_current_start;

  select count(*)::integer into v_total_audits from public.audit_logs;
  select count(*)::integer into v_current_audits from public.audit_logs where created_at >= v_current_start;
  select count(*)::integer into v_previous_audits from public.audit_logs where created_at >= v_previous_start and created_at < v_current_start;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'label', to_char(day_bucket.day, 'DD Mon'),
        'value', coalesce(user_counts.value, 0)
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
    from auth.users
    where created_at >= v_current_start
    group by created_at::date
  ) as user_counts
    on user_counts.day = day_bucket.day;

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
    'word_count', jsonb_build_object(
      'total', v_total_words,
      'delta', v_current_words - v_previous_words
    ),
    'reading_count', jsonb_build_object(
      'total', v_total_readings,
      'delta', v_current_readings - v_previous_readings
    ),
    'grammar_count', jsonb_build_object(
      'total', v_total_grammar,
      'delta', v_current_grammar - v_previous_grammar
    ),
    'audit_count', jsonb_build_object(
      'total', v_total_audits,
      'delta', v_current_audits - v_previous_audits
    ),
    'user_trend', v_trend,
    'maintenance_mode', coalesce((v_settings->'general'->>'maintenance_mode')::boolean, false)
  );
end;
$$;

create or replace function public.admin_set_content_publish_state(
  p_entity_type text,
  p_entity_id text,
  p_is_published boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  case p_entity_type
    when 'pack' then
      update public.packs
      set is_published = p_is_published,
          publish_at = null,
          unpublish_at = null,
          published_at = case
            when p_is_published then coalesce(published_at, now())
            else null
          end,
          updated_at = now(),
          updated_by = auth.uid()
      where id::text = p_entity_id;
    when 'reading' then
      update public.reading_passages
      set is_published = p_is_published,
          publish_at = null,
          unpublish_at = null,
          published_at = case
            when p_is_published then coalesce(published_at, now())
            else null
          end,
          updated_at = now(),
          updated_by = auth.uid()
      where id::text = p_entity_id;
    when 'word' then
      update public.words
      set is_published = p_is_published,
          publish_at = null,
          unpublish_at = null,
          published_at = case
            when p_is_published then coalesce(published_at, now())
            else null
          end,
          updated_at = now(),
          updated_by = auth.uid()
      where id::text = p_entity_id;
    when 'grammar' then
      update public.gramer_modulleri
      set is_published = p_is_published,
          publish_at = null,
          unpublish_at = null,
          published_at = case
            when p_is_published then coalesce(published_at, now())
            else null
          end,
          updated_at = now(),
          updated_by = auth.uid()
      where id::text = p_entity_id;
    else
      raise exception 'invalid entity type';
  end case;

  if not found then
    raise exception 'target entity not found';
  end if;

  perform public.write_audit_log(
    case
      when p_is_published then 'content.published'
      else 'content.unpublished'
    end,
    p_entity_type,
    p_entity_id,
    jsonb_build_object('is_published', p_is_published)
  );
end;
$$;

grant execute on function public.admin_default_settings() to authenticated;
grant execute on function public.admin_normalize_settings(jsonb) to authenticated;
grant execute on function public.admin_get_settings() to authenticated;
grant execute on function public.admin_upsert_settings(jsonb) to authenticated;
grant execute on function public.admin_apply_user_access(uuid, text, text, uuid, text) to authenticated, service_role;
grant execute on function public.admin_set_user_access(uuid, text, text) to authenticated;
grant execute on function public.admin_bulk_set_user_access(uuid[], text, text) to authenticated;
grant execute on function public.admin_assign_invited_user_access(uuid, text, text, uuid) to service_role;
grant execute on function public.admin_list_users_paged(text, text, text, text, integer, integer) to authenticated;
grant execute on function public.admin_list_packs() to authenticated;
grant execute on function public.admin_list_words_paged(uuid, text, text, integer, integer) to authenticated;
grant execute on function public.admin_list_reading_passages_paged(text, text, text, integer, integer) to authenticated;
grant execute on function public.admin_fetch_dashboard_snapshot(integer) to authenticated;
grant execute on function public.admin_set_content_publish_state(text, text, boolean) to authenticated;
