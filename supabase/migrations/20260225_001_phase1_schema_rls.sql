create extension if not exists pgcrypto;

create table if not exists public.packs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  from_lang text not null default 'en',
  to_lang text not null default 'tr',
  created_at timestamptz not null default now()
);

create unique index if not exists ux_packs_name on public.packs (name);

create table if not exists public.words (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid references public.packs(id) on delete cascade,
  en_word text not null,
  tr_meaning text not null,
  pos text not null,
  example_en text not null,
  example_tr text,
  synonyms_raw text,
  antonyms_raw text,
  level text,
  tags_raw text,
  notes text,
  created_at timestamptz not null default now(),
  constraint words_pos_check check (
    pos in ('noun','verb','adj','adv','prep','conj','pron','det','phrasal','idiom','other')
  )
);

create unique index if not exists ux_words_pack_en_pos on public.words (pack_id, en_word, pos);
create index if not exists ix_words_pack_id on public.words (pack_id);
create index if not exists ix_words_pack_pos on public.words (pack_id, pos);
create index if not exists ix_words_pack_en on public.words (pack_id, en_word);

create table if not exists public.user_word_progress (
  user_id uuid not null,
  word_id uuid not null references public.words(id) on delete cascade,
  mastery int not null default 0,
  seen_count int not null default 0,
  correct_count int not null default 0,
  wrong_count int not null default 0,
  last_seen_at timestamptz,
  last_answer text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, word_id),
  constraint progress_mastery_check check (mastery between 0 and 100),
  constraint progress_last_answer_check check (last_answer in ('known','unsure','unknown') or last_answer is null)
);

create index if not exists ix_progress_user_id on public.user_word_progress (user_id);
create index if not exists ix_progress_word_id on public.user_word_progress (word_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_progress_updated_at on public.user_word_progress;
create trigger trg_progress_updated_at
before update on public.user_word_progress
for each row execute function public.set_updated_at();

alter table public.packs enable row level security;
alter table public.words enable row level security;
alter table public.user_word_progress enable row level security;

grant usage on schema public to anon, authenticated;
grant select on table public.packs to anon, authenticated;
grant select on table public.words to anon, authenticated;
grant select, insert, update on table public.user_word_progress to authenticated;

drop policy if exists packs_select_all on public.packs;
create policy packs_select_all on public.packs
for select
to anon, authenticated
using (true);

drop policy if exists words_select_all on public.words;
create policy words_select_all on public.words
for select
to anon, authenticated
using (true);

drop policy if exists progress_select_own on public.user_word_progress;
create policy progress_select_own on public.user_word_progress
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists progress_insert_own on public.user_word_progress;
create policy progress_insert_own on public.user_word_progress
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists progress_update_own on public.user_word_progress;
create policy progress_update_own on public.user_word_progress
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

insert into public.packs (name)
select 'YDS Set 001'
where not exists (select 1 from public.packs where name = 'YDS Set 001');
