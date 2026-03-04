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

  -- packs truncation with cascade also clears static dependents and related progress rows.
  truncate table public.packs restart identity cascade;

  return jsonb_build_object(
    'status', 'ok',
    'method', 'truncate_packs_cascade',
    'tables', jsonb_build_array(
      'packs',
      'words (cascade)',
      'reading_passages (cascade)',
      'reading_passage_sentences (cascade)',
      'reading_passage_words (cascade)',
      'reading_sentence_translations (cascade)',
      'user_word_progress (cascade)',
      'user_reading_progress (cascade)'
    )
  );
end;
$$;

revoke all on function public.admin_reset_static_content() from public;
revoke all on function public.admin_reset_static_content() from anon;
revoke all on function public.admin_reset_static_content() from authenticated;
grant execute on function public.admin_reset_static_content() to service_role;
