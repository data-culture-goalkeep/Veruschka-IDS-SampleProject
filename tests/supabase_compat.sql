-- Local compatibility fixture only; never apply this file to hosted Supabase.
create role anon;
create role authenticated;
create role service_role bypassrls;
create schema auth;
create table auth.users(id uuid primary key);
-- Simulate inherited/global grants: per-object revokes must still close the model.
alter default privileges grant all on tables to anon, authenticated, service_role;
create function public.rls_auto_enable() returns event_trigger
language plpgsql security definer set search_path = pg_catalog as $$
declare cmd record; tbl name;
begin
  for cmd in select * from pg_event_trigger_ddl_commands()
    where command_tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO')
      and object_type in ('table','partitioned table')
  loop
    if cmd.schema_name = 'public' then
      begin
        select relname into tbl from pg_catalog.pg_class where oid = cmd.objid;
        execute format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
      exception when others then
        raise log 'local rls_auto_enable fixture failed for %', cmd.object_identity;
      end;
    end if;
  end loop;
end;
$$;
create event trigger ensure_rls on ddl_command_end
  when tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO')
  execute function public.rls_auto_enable();
alter default privileges grant execute on functions to anon, authenticated, service_role;
