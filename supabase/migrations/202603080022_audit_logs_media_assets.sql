create extension if not exists pgcrypto;

create table if not exists public.audit_logs (
  id bigserial primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text,
  payload_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  bucket_name text not null,
  storage_path text not null,
  mime_type text,
  is_published boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists ux_media_assets_storage_path
  on public.media_assets (bucket_name, storage_path);

drop trigger if exists trg_media_assets_updated_at on public.media_assets;
create trigger trg_media_assets_updated_at
before update on public.media_assets
for each row execute function public.set_updated_at();

create or replace function public.write_audit_log(
  p_action text,
  p_target_type text,
  p_target_id text,
  p_payload_json jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_logs (
    actor_user_id,
    action,
    target_type,
    target_id,
    payload_json
  )
  values (
    auth.uid(),
    p_action,
    p_target_type,
    p_target_id,
    coalesce(p_payload_json, '{}'::jsonb)
  );
end;
$$;

grant execute on function public.write_audit_log(text, text, text, jsonb) to authenticated;

alter table public.audit_logs enable row level security;
alter table public.media_assets enable row level security;

grant select on public.audit_logs to authenticated;
grant select on public.media_assets to anon, authenticated;

drop policy if exists audit_logs_select_admin on public.audit_logs;
create policy audit_logs_select_admin on public.audit_logs
for select
to authenticated
using (public.is_admin_or_developer());

drop policy if exists media_assets_select_visible on public.media_assets;
create policy media_assets_select_visible on public.media_assets
for select
to anon, authenticated
using (is_published or public.is_admin_or_developer());
