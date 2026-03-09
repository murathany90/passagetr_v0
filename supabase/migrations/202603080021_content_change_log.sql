create table if not exists public.content_change_log (
  id bigserial primary key,
  scope text not null,
  entity_type text not null,
  entity_id text not null,
  operation text not null,
  payload_json jsonb not null,
  changed_at timestamptz not null default now(),
  changed_by uuid references auth.users(id) on delete set null
);

create index if not exists ix_content_change_log_scope_id
  on public.content_change_log (scope, id);

create or replace function public.log_content_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entity_type text := tg_argv[0];
  v_scope text := tg_argv[1];
  v_payload jsonb;
  v_entity_id text;
begin
  v_payload := case
    when tg_op = 'DELETE' then to_jsonb(old)
    else to_jsonb(new)
  end;

  v_entity_id := coalesce(v_payload ->> 'id', '');

  insert into public.content_change_log (
    scope,
    entity_type,
    entity_id,
    operation,
    payload_json,
    changed_by
  )
  values (
    v_scope,
    v_entity_type,
    v_entity_id,
    lower(tg_op),
    v_payload,
    auth.uid()
  );

  perform public.bump_content_version(v_scope, v_entity_type || ':' || lower(tg_op));

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_packs_content_change on public.packs;
create trigger trg_packs_content_change
after insert or update or delete on public.packs
for each row execute function public.log_content_change('packs', 'packs');

drop trigger if exists trg_words_content_change on public.words;
create trigger trg_words_content_change
after insert or update or delete on public.words
for each row execute function public.log_content_change('words', 'words');

drop trigger if exists trg_readings_content_change on public.reading_passages;
create trigger trg_readings_content_change
after insert or update or delete on public.reading_passages
for each row execute function public.log_content_change('reading_passages', 'readings');

drop trigger if exists trg_grammar_modules_content_change on public.gramer_modulleri;
create trigger trg_grammar_modules_content_change
after insert or update or delete on public.gramer_modulleri
for each row execute function public.log_content_change('gramer_modulleri', 'grammar');

drop trigger if exists trg_grammar_pages_content_change on public.gramer_sayfalari;
create trigger trg_grammar_pages_content_change
after insert or update or delete on public.gramer_sayfalari
for each row execute function public.log_content_change('gramer_sayfalari', 'grammar');

alter table public.content_change_log enable row level security;
grant select on public.content_change_log to authenticated;

drop policy if exists content_change_log_select_admin on public.content_change_log;
create policy content_change_log_select_admin on public.content_change_log
for select
to authenticated
using (public.is_admin_or_developer());
