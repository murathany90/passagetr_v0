create table if not exists public.content_versions (
  scope text primary key,
  version bigint not null default 0,
  last_changed_at timestamptz not null default now(),
  last_changed_by uuid references auth.users(id) on delete set null,
  last_change_reason text
);

create or replace function public.bump_content_version(
  p_scope text,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.content_versions (
    scope,
    version,
    last_changed_at,
    last_changed_by,
    last_change_reason
  )
  values (
    p_scope,
    1,
    now(),
    auth.uid(),
    p_reason
  )
  on conflict (scope) do update
  set version = public.content_versions.version + 1,
      last_changed_at = now(),
      last_changed_by = auth.uid(),
      last_change_reason = p_reason;
end;
$$;

insert into public.content_versions (scope)
values ('packs'), ('words'), ('readings'), ('grammar')
on conflict (scope) do nothing;

alter table public.content_versions enable row level security;
grant select on public.content_versions to anon, authenticated;
grant execute on function public.bump_content_version(text, text) to authenticated;

drop policy if exists content_versions_select_all on public.content_versions;
create policy content_versions_select_all on public.content_versions
for select
to anon, authenticated
using (true);
