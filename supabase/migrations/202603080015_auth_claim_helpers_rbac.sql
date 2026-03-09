create or replace function public.current_app_role()
returns text
language sql
stable
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
as $$
  select public.current_app_role() in ('admin', 'developer');
$$;

create or replace function public.is_developer()
returns boolean
language sql
stable
as $$
  select public.current_app_role() = 'developer';
$$;

create or replace function public.can_read_published_content(
  p_is_published boolean,
  p_is_pro boolean
)
returns boolean
language sql
stable
as $$
  select coalesce(p_is_published, false)
    and (
      not coalesce(p_is_pro, false)
      or public.current_plan() = 'pro'
      or public.is_admin_or_developer()
    );
$$;

grant execute on function public.current_app_role() to anon, authenticated;
grant execute on function public.current_plan() to anon, authenticated;
grant execute on function public.is_admin_or_developer() to anon, authenticated;
grant execute on function public.is_developer() to anon, authenticated;
grant execute on function public.can_read_published_content(boolean, boolean) to anon, authenticated;

drop policy if exists profiles_select_admin on public.profiles;
create policy profiles_select_admin on public.profiles
for select
to authenticated
using (public.is_admin_or_developer());

drop policy if exists user_roles_select_admin on public.user_roles;
create policy user_roles_select_admin on public.user_roles
for select
to authenticated
using (public.is_admin_or_developer());

drop policy if exists entitlements_select_admin on public.entitlements;
create policy entitlements_select_admin on public.entitlements
for select
to authenticated
using (public.is_admin_or_developer());
