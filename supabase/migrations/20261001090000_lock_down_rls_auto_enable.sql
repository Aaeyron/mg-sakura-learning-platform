-- Supabase's "automatic RLS" project setting created public.rls_auto_enable(),
-- an event-trigger function. The database advisor warns that anon and
-- authenticated may execute it through the API. It can't really be called that
-- way (event-trigger functions only run as triggers), but we revoke access so
-- the advisor is clean. The trigger itself keeps working: Postgres doesn't
-- check EXECUTE when an event trigger fires.
-- Guarded, because the function only exists on projects with that setting on.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end;
$$;
