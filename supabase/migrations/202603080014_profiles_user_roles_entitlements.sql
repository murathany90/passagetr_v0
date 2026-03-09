create extension if not exists pgcrypto;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  preferred_locale text not null default 'tr',
  theme_mode text not null default 'system'
    check (theme_mode in ('light', 'dark', 'system')),
  onboarding_completed boolean not null default false,
  is_anonymous boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user', 'admin', 'developer')),
  granted_at timestamptz not null default now(),
  granted_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  unique (user_id, role)
);

create table if not exists public.entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan text not null check (plan in ('free', 'pro')),
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  source text not null default 'system',
  granted_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz
);

create index if not exists ix_user_roles_user_id on public.user_roles (user_id);
create index if not exists ix_entitlements_user_id on public.entitlements (user_id);

create or replace function public.set_profile_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_profile_updated_at();

create or replace function public.handle_new_user_defaults()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.profiles (
    user_id,
    display_name,
    preferred_locale,
    theme_mode,
    onboarding_completed,
    is_anonymous
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    coalesce(new.raw_user_meta_data ->> 'preferred_locale', 'tr'),
    coalesce(new.raw_user_meta_data ->> 'theme_mode', 'system'),
    false,
    coalesce((new.is_anonymous)::boolean, false)
  )
  on conflict (user_id) do nothing;

  insert into public.user_roles (user_id, role)
  values (new.id, 'user')
  on conflict (user_id, role) do nothing;

  insert into public.entitlements (user_id, plan, source)
  values (new.id, 'free', 'default_signup')
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_defaults on auth.users;
create trigger on_auth_user_created_defaults
after insert on auth.users
for each row execute function public.handle_new_user_defaults();

insert into public.profiles (user_id, is_anonymous)
select u.id, false
from auth.users u
where not exists (
  select 1
  from public.profiles p
  where p.user_id = u.id
);

insert into public.user_roles (user_id, role)
select u.id, 'user'
from auth.users u
where not exists (
  select 1
  from public.user_roles ur
  where ur.user_id = u.id
    and ur.role = 'user'
);

insert into public.entitlements (user_id, plan, source)
select u.id, 'free', 'backfill_default'
from auth.users u
where not exists (
  select 1
  from public.entitlements e
  where e.user_id = u.id
    and e.plan = 'free'
    and e.revoked_at is null
);

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.entitlements enable row level security;

grant select, update on public.profiles to authenticated;
grant select on public.user_roles to authenticated;
grant select on public.entitlements to authenticated;

drop policy if exists profiles_select_self on public.profiles;
create policy profiles_select_self on public.profiles
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists user_roles_select_self on public.user_roles;
create policy user_roles_select_self on public.user_roles
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists entitlements_select_self on public.entitlements;
create policy entitlements_select_self on public.entitlements
for select
to authenticated
using (auth.uid() = user_id);
