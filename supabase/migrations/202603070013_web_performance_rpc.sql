create or replace function public.get_packs_with_word_count()
returns table (
  id uuid,
  name text,
  from_lang text,
  to_lang text,
  word_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.name,
    p.from_lang,
    p.to_lang,
    count(w.id)::bigint as word_count
  from public.packs p
  left join public.words w on w.pack_id = p.id
  group by p.id, p.name, p.from_lang, p.to_lang
  order by p.name asc;
$$;

revoke all on function public.get_packs_with_word_count() from public;
grant execute on function public.get_packs_with_word_count() to anon, authenticated;

create or replace function public.get_word_level_counts()
returns table (
  level text,
  word_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    upper(w.level)::text as level,
    count(*)::bigint as word_count
  from public.words w
  where w.level is not null
    and btrim(w.level) <> ''
  group by upper(w.level)
  order by upper(w.level);
$$;

revoke all on function public.get_word_level_counts() from public;
grant execute on function public.get_word_level_counts() to anon, authenticated;

create or replace function public.get_studied_word_counts_by_level(
  p_levels text[] default null
)
returns table (
  level text,
  studied_word_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    upper(w.level)::text as level,
    count(distinct uwp.word_id)::bigint as studied_word_count
  from public.user_word_progress uwp
  join public.words w on w.id = uwp.word_id
  where uwp.user_id = auth.uid()
    and coalesce(uwp.seen_count, 0) > 0
    and (
      p_levels is null
      or upper(w.level) = any (
        select upper(item)
        from unnest(p_levels) as item
      )
    )
  group by upper(w.level)
  order by upper(w.level);
$$;

revoke all on function public.get_studied_word_counts_by_level(text[]) from public;
grant execute on function public.get_studied_word_counts_by_level(text[]) to authenticated;
