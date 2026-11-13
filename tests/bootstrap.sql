-- A real commit validates the source-equivalent Staff/Reference audit cycle.
begin;
set constraints all deferred;
insert into ids.reference_list(reference_value_id,list_name,display_label,created_by,updated_by)
values ('staff_type.DUMMY_BOOTSTRAP','staff_type','Dummy bootstrap','DUMMY-BOOTSTRAP-STAFF','DUMMY-BOOTSTRAP-STAFF');
insert into ids.staff(staff_id,staff_type_id,created_by,updated_by)
values ('DUMMY-BOOTSTRAP-STAFF','staff_type.DUMMY_BOOTSTRAP','DUMMY-BOOTSTRAP-STAFF','DUMMY-BOOTSTRAP-STAFF');
set constraints all immediate;
commit;
do $$ begin
  if not exists (
    select 1 from ids.staff s join ids.reference_list r on r.reference_value_id=s.staff_type_id
    where s.staff_id='DUMMY-BOOTSTRAP-STAFF' and r.created_by=s.staff_id and r.updated_by=s.staff_id
      and s.created_by=s.staff_id and s.updated_by=s.staff_id
  ) then raise exception 'Bootstrap did not preserve nonnull audit actors'; end if;
end $$;
begin;
set constraints all deferred;
delete from ids.reference_list where reference_value_id='staff_type.DUMMY_BOOTSTRAP';
delete from ids.staff where staff_id='DUMMY-BOOTSTRAP-STAFF';
commit;
