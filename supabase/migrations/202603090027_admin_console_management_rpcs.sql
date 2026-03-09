create or replace function public.admin_list_users()
returns table (
  user_id uuid,
  email text,
  display_name text,
  app_role text,
  plan text,
  is_anonymous boolean,
  last_seen_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public, auth
as $$
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
    coalesce(p.is_anonymous, false) as is_anonymous,
    u.last_sign_in_at as last_seen_at,
    coalesce(p.updated_at, u.created_at) as updated_at
  from auth.users u
  left join public.profiles p
    on p.user_id = u.id
  where public.is_admin_or_developer()
  order by coalesce(u.last_sign_in_at, u.created_at) desc, u.email asc;
$$;

create or replace function public.admin_list_words()
returns table (
  id text,
  pack_id text,
  en_word text,
  tr_meaning text,
  pos text,
  is_published boolean
)
language sql
security definer
set search_path = public
as $$
  select
    w.id::text,
    w.pack_id::text,
    coalesce(w.en_word, ''),
    coalesce(w.tr_meaning, ''),
    coalesce(w.pos, ''),
    coalesce(w.is_published, false)
  from public.words w
  where public.is_admin_or_developer()
  order by w.en_word asc;
$$;

create or replace function public.admin_list_reading_passages()
returns table (
  id text,
  title text,
  level text,
  category text,
  is_published boolean
)
language sql
security definer
set search_path = public
as $$
  select
    rp.id::text,
    coalesce(rp.title, ''),
    rp.level,
    rp.category,
    coalesce(rp.is_published, false)
  from public.reading_passages rp
  where public.is_admin_or_developer()
  order by rp.title asc;
$$;

create or replace function public.admin_list_grammar_modules()
returns table (
  id bigint,
  baslik text,
  toplam_sayfa integer,
  is_published boolean
)
language sql
security definer
set search_path = public
as $$
  select
    gm.id::bigint,
    coalesce(gm.baslik, ''),
    coalesce(gm.toplam_sayfa, 0),
    coalesce(gm.is_published, false)
  from public.gramer_modulleri gm
  where public.is_admin_or_developer()
  order by gm.sira asc nulls last, gm.id asc;
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
declare
  v_now timestamptz := now();
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if p_role not in ('user', 'admin', 'developer') then
    raise exception 'invalid role';
  end if;

  if p_plan not in ('free', 'pro') then
    raise exception 'invalid plan';
  end if;

  if p_role = 'developer' and not public.is_developer() then
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
    auth.uid(),
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
    and role <> p_role;

  if p_role in ('admin', 'developer') then
    insert into public.user_roles (
      user_id,
      role,
      granted_at,
      granted_by,
      revoked_at
    )
    values (
      p_user_id,
      p_role,
      v_now,
      auth.uid(),
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
    and plan <> p_plan;

  if not exists (
    select 1
    from public.entitlements e
    where e.user_id = p_user_id
      and e.plan = p_plan
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
      p_plan,
      v_now,
      'admin_console',
      auth.uid()
    );
  end if;

  perform public.write_audit_log(
    'admin.user_access.updated',
    'profiles',
    p_user_id::text,
    jsonb_build_object(
      'role', p_role,
      'plan', p_plan
    )
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
    when 'reading' then
      update public.reading_passages
      set is_published = p_is_published,
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

grant execute on function public.admin_list_users() to authenticated;
grant execute on function public.admin_list_words() to authenticated;
grant execute on function public.admin_list_reading_passages() to authenticated;
grant execute on function public.admin_list_grammar_modules() to authenticated;
grant execute on function public.admin_set_user_access(uuid, text, text) to authenticated;
grant execute on function public.admin_set_content_publish_state(text, text, boolean) to authenticated;
