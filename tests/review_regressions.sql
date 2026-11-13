begin;
create function pg_temp.assert_true(ok boolean, label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'Assertion failed: %', label; end if; end;
$$;
create function pg_temp.expect_failure(statement text, expected_state text) returns void language plpgsql as $$
begin
  begin execute statement;
  exception when others then if sqlstate = expected_state then return; end if; raise; end;
  raise exception 'Expected SQLSTATE %, statement succeeded: %', expected_state, statement;
end;
$$;

-- GitHub P1: sheet, file and row range must all agree with the actual checkpoint.
insert into ids_import.import_run(import_run_id,project_ref,source_file_id,approved_scope,source_timezone,source_manifest,status)
values ('44444444-4444-4444-8444-444444444444','uzofrrrtwqjmtytrbqfr','DUMMY-FILE','{}','Asia/Kolkata','{}','running');
insert into ids_import.import_chunk(import_chunk_id,import_run_id,source_sheet_id,first_row,last_row,payload_sha256,status)
values ('55555555-5555-4555-8555-555555555555','44444444-4444-4444-8444-444444444444',7,10,20,repeat('1',64),'pending');
insert into ids_import.source_row(source_row_id,import_run_id,import_chunk_id,source_file_id,source_sheet_id,source_tab,original_row,raw_values,raw_sha256,disposition)
values ('66666666-6666-4666-8666-666666666666','44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555','DUMMY-FILE',7,'Dummy',10,'{}',repeat('2',64),'staging_only');
insert into ids_import.source_row(import_run_id,import_chunk_id,source_file_id,source_sheet_id,source_tab,original_row,raw_values,raw_sha256)
values ('44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555','DUMMY-FILE',7,'Dummy',20,'{}',repeat('3',64));
select pg_temp.expect_failure($q$insert into ids_import.source_row(import_run_id,import_chunk_id,source_file_id,source_sheet_id,source_tab,original_row,raw_values,raw_sha256)
values ('44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555','DUMMY-FILE',99,'Dummy',11,'{}',repeat('0',64))$q$, '23503');
select pg_temp.expect_failure($q$insert into ids_import.source_row(import_run_id,import_chunk_id,source_file_id,source_sheet_id,source_tab,original_row,raw_values,raw_sha256)
values ('44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555','WRONG-FILE',7,'Dummy',12,'{}',repeat('0',64))$q$, '23503');
select pg_temp.expect_failure($q$insert into ids_import.source_row(import_run_id,import_chunk_id,source_file_id,source_sheet_id,source_tab,original_row,raw_values,raw_sha256)
values ('44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555','DUMMY-FILE',7,'Dummy',9,'{}',repeat('0',64))$q$, '23514');
select pg_temp.expect_failure($q$insert into ids_import.source_row(import_run_id,import_chunk_id,source_file_id,source_sheet_id,source_tab,original_row,raw_values,raw_sha256)
values ('44444444-4444-4444-8444-444444444444','55555555-5555-4555-8555-555555555555','DUMMY-FILE',7,'Dummy',21,'{}',repeat('0',64))$q$, '23514');
select pg_temp.expect_failure($q$update ids_import.source_row set chunk_first_row=1,chunk_last_row=99,original_row=8
where source_row_id='66666666-6666-4666-8666-666666666666'$q$, '23514');
select pg_temp.expect_failure($q$update ids_import.import_chunk set first_row=11 where import_chunk_id='55555555-5555-4555-8555-555555555555'$q$, '23503');
select pg_temp.expect_failure($q$update ids_import.import_chunk set source_sheet_id=8 where import_chunk_id='55555555-5555-4555-8555-555555555555'$q$, '23503');
select pg_temp.expect_failure($q$update ids_import.import_run set source_file_id='WRONG-FILE' where import_run_id='44444444-4444-4444-8444-444444444444'$q$, '23503');

-- Removing PUBLIC's inherited grant closes all ordinary API roles without breaking the event.
select pg_temp.assert_true(not has_function_privilege('anon','public.rls_auto_enable()','EXECUTE'), 'anon EXECUTE revoked');
select pg_temp.assert_true(not has_function_privilege('authenticated','public.rls_auto_enable()','EXECUTE'), 'authenticated EXECUTE revoked');
select pg_temp.assert_true(not has_function_privilege('service_role','public.rls_auto_enable()','EXECUTE'), 'service role no inherited EXECUTE');
select pg_temp.assert_true(has_function_privilege('postgres','public.rls_auto_enable()','EXECUTE'), 'owner retained');
select pg_temp.assert_true(not exists (
  select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
  where p.oid='public.rls_auto_enable()'::regprocedure and a.grantee=0 and a.privilege_type='EXECUTE'
), 'PUBLIC EXECUTE revoked');
create table public.dummy_event_trigger_probe(id integer);
select pg_temp.assert_true((select relrowsecurity from pg_class where oid='public.dummy_event_trigger_probe'::regclass), 'existing event still enables RLS');

-- Unknown obligation is not a zero-credit assertion, even if a payment exists.
select pg_temp.assert_true((select scheduled_net_due is null and balance is null and credit is null
  from ids.enrolment_fee_summary where enrolment_id='DUMMY-E2'), 'no-instalments unknowns');
insert into ids.fee_payment(payment_id,enrolment_id,amount,payment_type_id)
values ('DUMMY-NO-OBLIGATION-PAYMENT','DUMMY-E2',10,'payment_type.PAYMENT');
select pg_temp.assert_true((select net_paid=10 and credit is null
  from ids.enrolment_fee_summary where enrolment_id='DUMMY-E2'), 'payment does not invent an obligation');

-- Only definition/scoring columns are frozen, not source lineage or audit metadata.
update ids.criterion_catalogue set source_row_id='66666666-6666-4666-8666-666666666666',
  created_at='2026-01-01 09:00+05:30',updated_at='2026-01-02 09:00+05:30',
  created_by='DUMMY-STAFF',updated_by='DUMMY-STAFF' where criterion_id='DUMMY-CR1';
select pg_temp.assert_true((select source_row_id='66666666-6666-4666-8666-666666666666'::uuid
  and maximum_score=5 and criterion_name='Dummy criterion' from ids.criterion_catalogue where criterion_id='DUMMY-CR1'), 'provenance update preserved definition');
select pg_temp.expect_failure($q$update ids.criterion_catalogue set criterion_description='Changed definition' where criterion_id='DUMMY-CR1'$q$, '23514');
select pg_temp.expect_failure($q$update ids.criterion_catalogue set weight=2 where criterion_id='DUMMY-CR1'$q$, '23514');

-- Context is populated from parents; clients cannot spoof it to avoid an FK.
update ids.criterion_score set context_assessment_type_id='assessment_type.BASELINE',
  context_rubric_version='SPOOF', context_score_ceiling=999 where criterion_score_id='DUMMY-CS1';
select pg_temp.assert_true((select context_assessment_type_id='assessment_type.FUNCTIONAL'
  and context_rubric_version='DUMMY-RUBRIC' and context_score_ceiling=5
  from ids.criterion_score where criterion_score_id='DUMMY-CS1'), 'spoofed context overwritten');
set constraints all deferred;
update ids.goal set goal_section_id='goal_section.FUNCTIONAL_LEARNING' where goal_id='DUMMY-G1';
update ids.goal_review set goal_id=goal_id where goal_review_id='DUMMY-GR1';
set constraints all immediate;
select pg_temp.expect_failure($q$update ids.goal_review set faculty_rating_score=4 where goal_review_id='DUMMY-GR1'$q$, '23514');

-- There must be no nonunique index exactly duplicating a unique/primary key.
select pg_temp.assert_true(not exists (
  select 1 from pg_index i join pg_class c on c.oid=i.indrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in ('ids','ids_import') and not i.indisunique and i.indpred is null and i.indexprs is null
    and exists (select 1 from pg_index u where u.indrelid=i.indrelid and u.indisunique
      and u.indkey=i.indkey and u.indclass=i.indclass and u.indcollation=i.indcollation and u.indoption=i.indoption)
), 'exact redundant indexes removed');
rollback;
