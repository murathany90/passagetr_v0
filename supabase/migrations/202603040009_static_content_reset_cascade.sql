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

  truncate table
    public.reading_passage_words,
    public.reading_sentence_translations,
    public.reading_passage_sentences,
    public.reading_passages,
    public.words
  cascade;

  return jsonb_build_object(
    'status', 'ok',
    'method', 'truncate_cascade',
    'tables', jsonb_build_array(
      'reading_passage_words',
      'reading_sentence_translations',
      'reading_passage_sentences',
      'reading_passages',
      'words',
      'user_reading_progress (cascade)',
      'user_word_progress (cascade)'
    )
  );
end;
$$;

revoke all on function public.admin_reset_static_content() from public;
revoke all on function public.admin_reset_static_content() from anon;
revoke all on function public.admin_reset_static_content() from authenticated;
grant execute on function public.admin_reset_static_content() to service_role;
