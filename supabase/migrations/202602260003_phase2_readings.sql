create table if not exists public.reading_passages (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid references public.packs(id) on delete cascade,
  -- CSV import helper column (temporary but can be kept for operational ease)
  pack_name text,
  title text not null,
  level text,
  tags_raw text,
  source_url text,
  created_at timestamptz not null default now()
);

create index if not exists ix_reading_passages_pack_id
  on public.reading_passages (pack_id);

create index if not exists ix_reading_passages_title
  on public.reading_passages (title);

create table if not exists public.reading_passage_sentences (
  id uuid primary key default gen_random_uuid(),
  passage_id uuid references public.reading_passages(id) on delete cascade,
  -- CSV import helper column (temporary but can be kept for operational ease)
  passage_title text,
  idx int not null check (idx > 0),
  sentence_en text not null,
  sentence_tr text,
  created_at timestamptz not null default now(),
  unique (passage_id, idx)
);

create index if not exists ix_reading_sentences_passage_idx
  on public.reading_passage_sentences (passage_id, idx);

create index if not exists ix_reading_sentences_passage_title
  on public.reading_passage_sentences (passage_title);

create table if not exists public.reading_passage_words (
  passage_id uuid not null references public.reading_passages(id) on delete cascade,
  word_id uuid not null references public.words(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (passage_id, word_id)
);

create index if not exists ix_reading_passage_words_word_id
  on public.reading_passage_words (word_id);

create table if not exists public.reading_sentence_translations (
  id uuid primary key default gen_random_uuid(),
  sentence_id uuid not null references public.reading_passage_sentences(id) on delete cascade,
  provider text not null,
  target_lang text not null default 'tr',
  translated_text text not null,
  created_at timestamptz not null default now(),
  constraint ux_reading_sentence_translations_sentence_provider_lang
    unique (sentence_id, provider, target_lang)
);

comment on column public.reading_passages.pack_name is
  'CSV import helper column. Temporary by design, can be kept.';
comment on column public.reading_passage_sentences.passage_title is
  'CSV import helper column. Temporary by design, can be kept.';

create index if not exists ix_reading_sentence_translations_sentence_id
  on public.reading_sentence_translations (sentence_id);

alter table public.reading_passages enable row level security;
alter table public.reading_passage_sentences enable row level security;
alter table public.reading_passage_words enable row level security;
alter table public.reading_sentence_translations enable row level security;

grant select on table public.reading_passages to anon, authenticated;
grant select on table public.reading_passage_sentences to anon, authenticated;
grant select on table public.reading_passage_words to anon, authenticated;
grant select on table public.reading_sentence_translations to anon, authenticated;
grant insert, update on table public.reading_sentence_translations to authenticated;

drop policy if exists reading_passages_select_all on public.reading_passages;
create policy reading_passages_select_all on public.reading_passages
for select
to anon, authenticated
using (true);

drop policy if exists reading_passage_sentences_select_all on public.reading_passage_sentences;
create policy reading_passage_sentences_select_all on public.reading_passage_sentences
for select
to anon, authenticated
using (true);

drop policy if exists reading_passage_words_select_all on public.reading_passage_words;
create policy reading_passage_words_select_all on public.reading_passage_words
for select
to anon, authenticated
using (true);

drop policy if exists reading_sentence_translations_select_all on public.reading_sentence_translations;
create policy reading_sentence_translations_select_all on public.reading_sentence_translations
for select
to anon, authenticated
using (true);

drop policy if exists reading_sentence_translations_insert_auth on public.reading_sentence_translations;
create policy reading_sentence_translations_insert_auth on public.reading_sentence_translations
for insert
to authenticated
with check (auth.uid() is not null);

drop policy if exists reading_sentence_translations_update_auth on public.reading_sentence_translations;
create policy reading_sentence_translations_update_auth on public.reading_sentence_translations
for update
to authenticated
using (auth.uid() is not null)
with check (auth.uid() is not null);
