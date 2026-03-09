create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    nullif(auth.jwt() ->> 'app_role', ''),
    (
      select ur.role
      from public.user_roles ur
      where ur.user_id = auth.uid()
        and ur.revoked_at is null
      order by case ur.role
        when 'developer' then 3
        when 'admin' then 2
        else 1
      end desc
      limit 1
    ),
    'user'
  );
$$;

create or replace function public.current_plan()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select coalesce(
    nullif(auth.jwt() ->> 'plan', ''),
    (
      select e.plan
      from public.entitlements e
      where e.user_id = auth.uid()
        and e.revoked_at is null
        and e.starts_at <= now()
        and (e.expires_at is null or e.expires_at > now())
      order by e.starts_at desc
      limit 1
    ),
    'free'
  );
$$;

create or replace function public.is_admin_or_developer()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select public.current_app_role() in ('admin', 'developer');
$$;

create or replace function public.is_developer()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select public.current_app_role() = 'developer';
$$;

grant execute on function public.current_app_role() to anon, authenticated;
grant execute on function public.current_plan() to anon, authenticated;
grant execute on function public.is_admin_or_developer() to anon, authenticated;
grant execute on function public.is_developer() to anon, authenticated;
