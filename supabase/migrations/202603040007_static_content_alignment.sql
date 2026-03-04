alter table public.words
  add column if not exists pos_raw text;

alter table public.words
  drop constraint if exists words_pos_check;

alter table public.words
  add constraint words_pos_check check (
    pos ~ '^(prep\\.|phr\\. v\\.|v\\.|n\\.|adj\\.|adv\\.|NP|conj\\.|det\\.|modal)(;(prep\\.|phr\\. v\\.|v\\.|n\\.|adj\\.|adv\\.|NP|conj\\.|det\\.|modal))*$'
  ) not valid;

alter table public.reading_passages
  add column if not exists category text;

alter table public.reading_passages
  drop column if exists source_url;

create index if not exists ix_reading_passages_category
  on public.reading_passages (category);

create or replace function public.admin_reset_static_content()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  role_name text := coalesce(auth.jwt()->>'role', '');
begin
  if role_name <> 'service_role' then
    raise exception 'forbidden: service_role required';
  end if;

  delete from public.reading_passage_words;
  delete from public.reading_sentence_translations;
  delete from public.reading_passage_sentences;
  delete from public.reading_passages;
  delete from public.words;

  return jsonb_build_object(
    'status', 'ok',
    'deleted', jsonb_build_object(
      'reading_passage_words', true,
      'reading_sentence_translations', true,
      'reading_passage_sentences', true,
      'reading_passages', true,
      'words', true
    )
  );
end;
$$;

revoke all on function public.admin_reset_static_content() from public;
revoke all on function public.admin_reset_static_content() from anon;
revoke all on function public.admin_reset_static_content() from authenticated;
grant execute on function public.admin_reset_static_content() to service_role;
