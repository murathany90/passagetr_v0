create or replace function public.set_content_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

alter table public.packs
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists published_at timestamptz,
  add column if not exists is_published boolean not null default true,
  add column if not exists is_pro boolean not null default false,
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists updated_by uuid references auth.users(id) on delete set null;

alter table public.words
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists published_at timestamptz,
  add column if not exists is_published boolean not null default true,
  add column if not exists is_pro boolean not null default false,
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists updated_by uuid references auth.users(id) on delete set null;

alter table public.reading_passages
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists published_at timestamptz,
  add column if not exists is_published boolean not null default true,
  add column if not exists is_pro boolean not null default false,
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists updated_by uuid references auth.users(id) on delete set null;

alter table public.gramer_modulleri
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists published_at timestamptz,
  add column if not exists is_published boolean not null default true,
  add column if not exists is_pro boolean not null default false,
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists updated_by uuid references auth.users(id) on delete set null;

alter table public.gramer_sayfalari
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists published_at timestamptz,
  add column if not exists is_published boolean not null default true,
  add column if not exists is_pro boolean not null default false,
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists updated_by uuid references auth.users(id) on delete set null;

alter table public.gramer_ornekler
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists published_at timestamptz,
  add column if not exists is_published boolean not null default true,
  add column if not exists is_pro boolean not null default false,
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists updated_by uuid references auth.users(id) on delete set null;

alter table public.gramer_testler
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists published_at timestamptz,
  add column if not exists is_published boolean not null default true,
  add column if not exists is_pro boolean not null default false,
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists updated_by uuid references auth.users(id) on delete set null;

drop trigger if exists trg_packs_updated_at on public.packs;
create trigger trg_packs_updated_at
before update on public.packs
for each row execute function public.set_content_updated_at();

drop trigger if exists trg_words_updated_at_content on public.words;
create trigger trg_words_updated_at_content
before update on public.words
for each row execute function public.set_content_updated_at();

drop trigger if exists trg_readings_updated_at on public.reading_passages;
create trigger trg_readings_updated_at
before update on public.reading_passages
for each row execute function public.set_content_updated_at();

drop trigger if exists trg_grammar_modules_updated_at on public.gramer_modulleri;
create trigger trg_grammar_modules_updated_at
before update on public.gramer_modulleri
for each row execute function public.set_content_updated_at();

drop policy if exists packs_select_all on public.packs;
create policy packs_select_all on public.packs
for select
to anon, authenticated
using (public.can_read_published_content(is_published, is_pro));

drop policy if exists words_select_all on public.words;
create policy words_select_all on public.words
for select
to anon, authenticated
using (public.can_read_published_content(is_published, is_pro));

drop policy if exists reading_passages_select_all on public.reading_passages;
create policy reading_passages_select_all on public.reading_passages
for select
to anon, authenticated
using (public.can_read_published_content(is_published, is_pro));

drop policy if exists reading_passage_sentences_select_all on public.reading_passage_sentences;
create policy reading_passage_sentences_select_all on public.reading_passage_sentences
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.reading_passages rp
    where rp.id = passage_id
      and public.can_read_published_content(rp.is_published, rp.is_pro)
  )
);

drop policy if exists reading_passage_words_select_all on public.reading_passage_words;
create policy reading_passage_words_select_all on public.reading_passage_words
for select
to anon, authenticated
using (
  exists (
    select 1
    from public.reading_passages rp
    where rp.id = passage_id
      and public.can_read_published_content(rp.is_published, rp.is_pro)
  )
);

drop policy if exists gramer_modulleri_select_all on public.gramer_modulleri;
create policy gramer_modulleri_select_all on public.gramer_modulleri
for select
to anon, authenticated
using (public.can_read_published_content(is_published, is_pro));

drop policy if exists gramer_sayfalari_select_all on public.gramer_sayfalari;
create policy gramer_sayfalari_select_all on public.gramer_sayfalari
for select
to anon, authenticated
using (public.can_read_published_content(is_published, is_pro));

drop policy if exists gramer_ornekler_select_all on public.gramer_ornekler;
create policy gramer_ornekler_select_all on public.gramer_ornekler
for select
to anon, authenticated
using (public.can_read_published_content(is_published, is_pro));

drop policy if exists gramer_testler_select_all on public.gramer_testler;
create policy gramer_testler_select_all on public.gramer_testler
for select
to anon, authenticated
using (public.can_read_published_content(is_published, is_pro));
