create or replace function public.admin_import_readings(
  p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_item jsonb;
  v_count integer := 0;
begin
  if not public.is_admin_or_developer() then
    raise exception 'admin privileges required';
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'array' then
    raise exception 'payload must be a json array';
  end if;

  for v_item in
    select value
    from jsonb_array_elements(p_payload)
  loop
    perform public.admin_upsert_reading_detail(v_item);
    v_count := v_count + 1;
  end loop;

  insert into public.audit_logs (
    actor_user_id,
    action,
    target_type,
    target_id,
    payload_json
  )
  values (
    auth.uid(),
    'admin.reading.imported',
    'reading_passages',
    null,
    jsonb_build_object('count', v_count)
  );
end;
$$;

grant execute on function public.admin_import_readings(jsonb) to authenticated;
