begin;
create function pg_temp.assert_true(ok boolean, label text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'Assertion failed: %', label; end if;
end;
$$;
create function pg_temp.expect_failure(statement text, expected_state text) returns void language plpgsql as $$
begin
  begin
    execute statement;
  exception when others then
    if sqlstate = expected_state then return; end if;
    raise;
  end;
  raise exception 'Expected SQLSTATE %, statement succeeded: %', expected_state, statement;
end;
$$;

select pg_temp.assert_true((select count(*) = 28 from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in ('ids','ids_import') and c.relkind='r'), '24 model + 4 audit tables');
select pg_temp.assert_true(not exists (
  select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in ('ids','ids_import') and c.relkind='r' and not c.relrowsecurity), 'RLS on every table');
select pg_temp.assert_true(not exists (
  select 1 from pg_policies where schemaname in ('ids','ids_import')), 'zero policies');
select pg_temp.assert_true(not exists (
  select 1 from pg_namespace n cross join (values ('anon'),('authenticated'),('service_role')) r(role_name)
  where n.nspname in ('ids','ids_import') and has_schema_privilege(r.role_name,n.oid,'USAGE')), 'no API-role schema access');
select pg_temp.assert_true(not exists (
  select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
  cross join (values ('anon'),('authenticated'),('service_role')) r(role_name)
  where n.nspname in ('ids','ids_import') and c.relkind in ('r','v')
    and has_table_privilege(r.role_name,c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')), 'no API-role table or view privileges');
select pg_temp.assert_true(not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('ids','ids_import') and (p.prosecdef or p.proconfig is null)), 'private invoker functions with fixed search path');
select pg_temp.assert_true(not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  cross join (values ('anon'),('authenticated'),('service_role')) r(role_name)
  where n.nspname in ('ids','ids_import') and has_function_privilege(r.role_name,p.oid,'EXECUTE')), 'no API-role function execution');
select pg_temp.assert_true((select count(*)=2 from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='ids' and c.relkind='v' and c.reloptions @> array['security_invoker=true']), 'both views invoke caller security');
select pg_temp.assert_true(not exists (
  select 1 from pg_constraint fk join pg_namespace n on n.oid=fk.connamespace
  where n.nspname in ('ids','ids_import') and fk.contype='f'
  and not exists (select 1 from pg_index ix where ix.indrelid=fk.conrelid and ix.indisvalid
    and array(select ix.indkey[k] from generate_series(0,cardinality(fk.conkey)-1) k) = fk.conkey)), 'FK indexes exist');
select pg_temp.assert_true((select count(*)=154 from ids.reference_list), '154 authoritative options');
select pg_temp.assert_true((select count(distinct list_name)=52 from ids.reference_list), '52 authoritative lists');
select pg_temp.assert_true((select is_nullable='NO' from information_schema.columns
  where table_schema='ids' and table_name='learner_sensitive_details' and column_name='aadhaar_number'), 'Aadhaar mandatory');
select pg_temp.assert_true((select data_type='boolean' from information_schema.columns
  where table_schema='ids' and table_name='enrolment' and column_name='docs_provided'), 'docs_provided boolean');
select pg_temp.assert_true((select batch_schedule_id is null from ids.assessment_event where assessment_event_id='DUMMY-A1'), 'assessment session optional');
select pg_temp.assert_true((select next_follow_up_date is null from ids.mobilisation_activity where activity_id='DUMMY-ACTIVITY'), 'activity date starts null');

-- One lead per non-null learner; many unconverted leads remain permitted.
select pg_temp.expect_failure($q$insert into ids.mobilisation_lead(candidate_id,learner_id) values ('DUMMY-DUP','DUMMY-L1')$q$, '23505');
insert into ids.mobilisation_lead(candidate_id) values ('DUMMY-NULL-1'),('DUMMY-NULL-2');
select pg_temp.expect_failure($q$insert into ids.learner_sensitive_details(learner_id,aadhaar_number) values ('DUMMY-L2',null)$q$, '23502');
select pg_temp.expect_failure($q$insert into ids.learner_sensitive_details(learner_id,aadhaar_number) values ('DUMMY-L2','   ')$q$, '23514');
select pg_temp.expect_failure($q$insert into ids.mobilisation_lead(candidate_id,learner_id) values ('DUMMY-ORPHAN','NO-SUCH-LEARNER')$q$, '23503');
select pg_temp.expect_failure($q$insert into ids.batch(batch_id,program_id) values ('DUMMY-BAD-ENUM','shift.MORNING')$q$, '23514');
select pg_temp.expect_failure($q$update ids.batch set program_id='programme.MISSING' where batch_id='DUMMY-B2'$q$, '23503');
select pg_temp.expect_failure($q$insert into ids.batch_schedule(batch_schedule_id,batch_id,week_number,session_number) values ('DUMMY-DUP-SESSION','DUMMY-B1',1,1)$q$, '23505');
select pg_temp.expect_failure($q$insert into ids.batch_schedule(batch_schedule_id,batch_id,week_number,session_number) values ('DUMMY-S4','DUMMY-B1',1,4)$q$, '23514');

-- Cross-table ownership and batch consistency, including parent mutations.
select pg_temp.expect_failure($q$update ids.enrolment set supporter_contact_id='DUMMY-C2' where enrolment_id='DUMMY-E1'$q$, '23503');
select pg_temp.expect_failure($q$update ids.family_contact set learner_id='DUMMY-L2' where contact_id='DUMMY-C1'$q$, '23503');
select pg_temp.expect_failure($q$insert into ids.learner_session_log(learner_session_log_id,enrolment_id,batch_schedule_id) values ('DUMMY-WRONG-BATCH','DUMMY-E1','DUMMY-S3')$q$, '23503');
select pg_temp.expect_failure($q$update ids.batch_schedule set batch_id='DUMMY-B2', week_number=2 where batch_schedule_id='DUMMY-S1'$q$, '23503');
select pg_temp.expect_failure($q$update ids.assessment_event set supported_by_contact_id='DUMMY-C2' where assessment_event_id='DUMMY-A1'$q$, '23503');
select pg_temp.expect_failure($q$insert into ids.criterion_score(criterion_score_id,assessment_event_id,criterion_id) values ('DUMMY-WRONG-RUBRIC','DUMMY-A1','DUMMY-CR2')$q$, '23503');
select pg_temp.expect_failure($q$update ids.assessment_event set rubric_version='DUMMY-OTHER-RUBRIC' where assessment_event_id='DUMMY-A1'$q$, '23503');
select pg_temp.expect_failure($q$update ids.criterion_catalogue set maximum_score=4 where criterion_id='DUMMY-CR1'$q$, '23514');
select pg_temp.expect_failure($q$update ids.criterion_score set score_value=6 where criterion_score_id='DUMMY-CS1'$q$, '23514');
select pg_temp.expect_failure($q$update ids.goal_review set faculty_rating_score=0 where goal_review_id='DUMMY-GR1'$q$, '23514');
select pg_temp.expect_failure($q$update ids.goal_review set milestone_week=5 where goal_review_id='DUMMY-GR1'$q$, '23514');
select pg_temp.expect_failure($q$update ids.goal_review set ideal_seed_pathway='seed_pathway.OTHER' where goal_review_id='DUMMY-GR1'$q$, '23514');
select pg_temp.expect_failure($q$update ids.batch set program_id='programme.SEED' where batch_id='DUMMY-B1'$q$, '23503');

-- Fees: 100 due; 75 payment minus 5 refund; oldest obligation receives 40, next 30.
select pg_temp.assert_true((select scheduled_net_due=100 and net_paid=70 and balance=30 and credit=0
  from ids.enrolment_fee_summary where enrolment_id='DUMMY-E1'), 'fee totals preserve source obligations');
select pg_temp.assert_true((select amount_paid=40 and amount_remaining=0 and derived_status_id='fee_status.PAID'
  from ids.fee_instalment_balance where instalment_id='DUMMY-I1'), 'oldest instalment first');
select pg_temp.assert_true((select amount_paid=30 and amount_remaining=30 and derived_status_id='fee_status.PENDING'
  from ids.fee_instalment_balance where instalment_id='DUMMY-I2'), 'second instalment partial allocation');
select pg_temp.expect_failure($q$insert into ids.fee_payment(payment_id,enrolment_id,amount,payment_type_id) values ('DUMMY-NEG','DUMMY-E1',-1,'payment_type.PAYMENT')$q$, '23514');
insert into ids.fee_payment(payment_id,enrolment_id,amount,payment_type_id) values ('DUMMY-EXCESS','DUMMY-E1',50,'payment_type.PAYMENT');
select pg_temp.assert_true((select credit=20 from ids.enrolment_fee_summary where enrolment_id='DUMMY-E1'), 'overpayment remains credit');

-- Preserve the explicitly accepted anomalies and unknowns.
select pg_temp.assert_true((select count(*)=1 from ids.learner_session_log l join ids.batch_schedule s using(batch_schedule_id)
  where s.delivery_status_id='delivery_status.HOLIDAY' and s.actual_session_date is not null), 'Holiday date/log allowed');
select pg_temp.assert_true((select mou_signed_date is null from ids.partner_organisation where partner_organisation_id='DUMMY-PARTNER'), 'MOU mismatch allowed');
update ids.goal_review set faculty_rating_score=null where goal_review_id='DUMMY-GR1';
update ids.learner_profile set gender='unresolved source value', apl_bpl='unresolved source value' where learner_id='DUMMY-L1';

-- Optional family login can map to several learners; Staff login is unique.
insert into auth.users(id) values ('11111111-1111-4111-8111-111111111111');
update ids.family_contact set auth_user_id='11111111-1111-4111-8111-111111111111';
update ids.staff set auth_user_id='11111111-1111-4111-8111-111111111111';
select pg_temp.expect_failure($q$insert into ids.staff(staff_id,auth_user_id) values ('DUMMY-STAFF2','11111111-1111-4111-8111-111111111111')$q$, '23505');

-- Audit context is allowlisted and row identities are retry-safe within a run.
select pg_temp.expect_failure($q$insert into ids_import.import_run(project_ref,source_file_id,approved_scope,source_timezone,source_manifest,status) values ('wrong-project','DUMMY','{}','Asia/Kolkata','{}','pending')$q$, '23514');
insert into ids_import.import_run(import_run_id,project_ref,source_file_id,approved_scope,source_timezone,source_manifest,status)
values ('22222222-2222-4222-8222-222222222222','uzofrrrtwqjmtytrbqfr','DUMMY','{}','Asia/Kolkata','{}','running');
insert into ids_import.source_row(source_row_id,import_run_id,source_file_id,source_sheet_id,source_tab,original_row,raw_values,raw_sha256,disposition)
values ('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222','DUMMY',1,'Dummy',3,'{}',repeat('0',64),'staging_only');
select pg_temp.expect_failure($q$insert into ids_import.source_row(import_run_id,source_file_id,source_sheet_id,source_tab,original_row,raw_values,raw_sha256) values ('22222222-2222-4222-8222-222222222222','DUMMY',1,'Dummy',3,'{}',repeat('0',64))$q$, '23505');
insert into ids_import.validation_issue(source_row_id,severity,reason_code,reason)
values ('33333333-3333-4333-8333-333333333333','warning','DUMMY_WARNING','Approved source exception; no raw values in reason');
select pg_temp.assert_true((select disposition='staging_only' from ids_import.source_row
  where source_row_id='33333333-3333-4333-8333-333333333333'), 'warning is not quarantine');

-- Exercise actual denied queries, not only ACL inspection.
set local role anon;
do $$ begin
  begin perform 1 from ids.learner_profile; raise exception 'anon read unexpectedly succeeded';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
do $$ begin
  begin perform 1 from ids.learner_sensitive_details; raise exception 'authenticated read unexpectedly succeeded';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
