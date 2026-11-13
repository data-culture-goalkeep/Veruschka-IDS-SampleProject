-- Review fixes only. Hosted application still requires explicit approval.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

-- Preserve the platform event trigger; remove unnecessary inherited execution.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- Bind provenance to the run's file and the exact chunk sheet/range.
alter table ids_import.import_run add unique (import_run_id, source_file_id);
alter table ids_import.import_chunk add unique
  (import_chunk_id, import_run_id, source_sheet_id, first_row, last_row);
alter table ids_import.source_row
  drop constraint source_row_import_chunk_id_import_run_id_fkey,
  add column chunk_first_row integer,
  add column chunk_last_row integer,
  add foreign key (import_run_id, source_file_id)
    references ids_import.import_run(import_run_id, source_file_id),
  add foreign key (import_chunk_id, import_run_id, source_sheet_id, chunk_first_row, chunk_last_row)
    references ids_import.import_chunk(import_chunk_id, import_run_id, source_sheet_id, first_row, last_row),
  add check (
    (import_chunk_id is null and chunk_first_row is null and chunk_last_row is null)
    or (import_chunk_id is not null and chunk_first_row is not null and chunk_last_row is not null
        and original_row between chunk_first_row and chunk_last_row)
  );
create function ids_import.fill_chunk_bounds() returns trigger
language plpgsql security invoker set search_path = pg_catalog as $$
begin
  if new.import_chunk_id is null then
    new.chunk_first_row := null;
    new.chunk_last_row := null;
  else
    select first_row, last_row into strict new.chunk_first_row, new.chunk_last_row
      from ids_import.import_chunk
      where import_chunk_id = new.import_chunk_id and import_run_id = new.import_run_id;
  end if;
  return new;
exception when no_data_found then
  raise exception using errcode = '23503', message = 'source_chunk_run_missing';
end;
$$;
create trigger fill_chunk_bounds before insert or update on ids_import.source_row
for each row execute function ids_import.fill_chunk_bounds();
update ids_import.source_row set import_chunk_id = import_chunk_id;
create index on ids_import.source_row(import_run_id, source_file_id);
create index on ids_import.source_row
  (import_chunk_id, import_run_id, source_sheet_id, chunk_first_row, chunk_last_row);

-- Use declarative context keys for learner/contact/batch/rubric relationships.
alter table ids.family_contact add unique(contact_id, learner_id);
alter table ids.enrolment add unique(enrolment_id, learner_id, batch_id);
alter table ids.enrolment add foreign key (supporter_contact_id, learner_id)
  references ids.family_contact(contact_id, learner_id) deferrable initially immediate;
create index on ids.enrolment(supporter_contact_id, learner_id);
alter table ids.batch add unique(batch_id, program_id);
alter table ids.batch_schedule add unique(batch_schedule_id, batch_id);
alter table ids.assessment_event add unique(assessment_event_id, assessment_type_id, rubric_version);
alter table ids.criterion_catalogue add column context_score_ceiling numeric
  generated always as (coalesce(maximum_score, 'Infinity'::numeric)) stored;
alter table ids.criterion_catalogue alter column context_score_ceiling set not null;
alter table ids.criterion_catalogue add unique
  (criterion_id, assessment_type_id, rubric_version, context_score_ceiling);
alter table ids.goal add column context_section_key text
  generated always as (coalesce(goal_section_id, '')) stored;
alter table ids.goal alter column context_section_key set not null;
alter table ids.goal add unique(goal_id, context_section_key);

alter table ids.goal add column context_learner_id text, add column context_batch_id text,
  add column context_programme_id text generated always as ('programme.ILS'::text) stored;
alter table ids.assessment_event add column context_learner_id text, add column context_batch_id text;
alter table ids.learner_session_log add column context_learner_id text, add column context_batch_id text;
alter table ids.criterion_score add column context_assessment_type_id text,
  add column context_rubric_version text, add column context_score_ceiling numeric;
alter table ids.goal_review add column context_section_key text;

-- Fill only derived integrity metadata; never rewrite source fields.
create or replace function ids.check_row_context() returns trigger
language plpgsql security invoker set search_path = pg_catalog as $$
declare e ids.enrolment%rowtype; ev ids.assessment_event%rowtype; cr ids.criterion_catalogue%rowtype;
begin
  if tg_table_name in ('goal', 'assessment_event', 'learner_session_log') then
    select * into strict e from ids.enrolment where enrolment_id = new.enrolment_id;
    new.context_learner_id := e.learner_id;
    new.context_batch_id := e.batch_id;
  elsif tg_table_name = 'criterion_score' then
    select * into strict ev from ids.assessment_event where assessment_event_id = new.assessment_event_id;
    -- SHARE, rather than KEY SHARE, also serializes descriptive rubric changes.
    select * into strict cr from ids.criterion_catalogue where criterion_id = new.criterion_id for share;
    new.context_assessment_type_id := ev.assessment_type_id;
    new.context_rubric_version := ev.rubric_version;
    new.context_score_ceiling := cr.context_score_ceiling;
  elsif tg_table_name = 'goal_review' then
    select context_section_key into strict new.context_section_key
      from ids.goal where goal_id = new.goal_id;
  end if;
  return new;
exception when no_data_found then
  raise exception using errcode = '23503', message = 'required_context_parent_missing';
end;
$$;
drop trigger check_enrolment_context on ids.enrolment;
drop trigger check_contact_dependants on ids.family_contact;
drop trigger check_enrolment_dependants on ids.enrolment;
drop trigger check_schedule_dependants on ids.batch_schedule;
drop trigger check_goal_dependants on ids.goal;
drop trigger check_assessment_dependants on ids.assessment_event;
drop trigger check_batch_dependants on ids.batch;
drop function ids.check_parent_context();

update ids.goal set enrolment_id = enrolment_id;
update ids.assessment_event set enrolment_id = enrolment_id;
update ids.learner_session_log set enrolment_id = enrolment_id;
update ids.criterion_score set criterion_id = criterion_id;
update ids.goal_review set goal_id = goal_id;

alter table ids.goal alter column context_learner_id set not null, alter column context_batch_id set not null,
  alter column context_programme_id set not null;
alter table ids.assessment_event alter column context_learner_id set not null, alter column context_batch_id set not null;
alter table ids.learner_session_log alter column context_learner_id set not null, alter column context_batch_id set not null;
alter table ids.criterion_score alter column context_assessment_type_id set not null,
  alter column context_rubric_version set not null, alter column context_score_ceiling set not null;
alter table ids.goal_review alter column context_section_key set not null;

alter table ids.goal
  add foreign key (enrolment_id, context_learner_id, context_batch_id)
    references ids.enrolment(enrolment_id, learner_id, batch_id) deferrable initially immediate,
  add foreign key (responsible_contact_id, context_learner_id)
    references ids.family_contact(contact_id, learner_id) deferrable initially immediate,
  add foreign key (context_batch_id, context_programme_id)
    references ids.batch(batch_id, program_id) deferrable initially immediate;
alter table ids.assessment_event
  add foreign key (enrolment_id, context_learner_id, context_batch_id)
    references ids.enrolment(enrolment_id, learner_id, batch_id) deferrable initially immediate,
  add foreign key (supported_by_contact_id, context_learner_id)
    references ids.family_contact(contact_id, learner_id) deferrable initially immediate,
  add foreign key (batch_schedule_id, context_batch_id)
    references ids.batch_schedule(batch_schedule_id, batch_id) deferrable initially immediate;
alter table ids.learner_session_log
  add foreign key (enrolment_id, context_learner_id, context_batch_id)
    references ids.enrolment(enrolment_id, learner_id, batch_id) deferrable initially immediate,
  add foreign key (batch_schedule_id, context_batch_id)
    references ids.batch_schedule(batch_schedule_id, batch_id) deferrable initially immediate;
alter table ids.criterion_score
  add foreign key (assessment_event_id, context_assessment_type_id, context_rubric_version)
    references ids.assessment_event(assessment_event_id, assessment_type_id, rubric_version) deferrable initially immediate,
  add foreign key (criterion_id, context_assessment_type_id, context_rubric_version, context_score_ceiling)
    references ids.criterion_catalogue(criterion_id, assessment_type_id, rubric_version, context_score_ceiling) deferrable initially immediate,
  add check (score_value <= context_score_ceiling);
alter table ids.goal_review
  add foreign key (goal_id, context_section_key) references ids.goal(goal_id, context_section_key)
    deferrable initially immediate,
  add check (
    case context_section_key
      when 'goal_section.SMART_GOALS' then
        (faculty_rating_score between 1 and 4) and (family_rating_score between 1 and 4)
      when 'goal_section.FUNCTIONAL_LEARNING' then
        (faculty_rating_score between 0 and 3) and (family_rating_score between 0 and 3)
      when 'goal_section.HOSPITALITY' then
        (faculty_rating_score between 0 and 3) and (family_rating_score between 0 and 3)
      else true
    end
  );
-- Context keys contain no inferred business facts: they mirror existing parent keys.
create index on ids.goal(enrolment_id, context_learner_id, context_batch_id);
create index on ids.goal(responsible_contact_id, context_learner_id);
create index on ids.goal(context_batch_id, context_programme_id);
create index on ids.assessment_event(enrolment_id, context_learner_id, context_batch_id);
create index on ids.assessment_event(supported_by_contact_id, context_learner_id);
create index on ids.assessment_event(batch_schedule_id, context_batch_id);
create index on ids.learner_session_log(enrolment_id, context_learner_id, context_batch_id);
create index on ids.learner_session_log(batch_schedule_id, context_batch_id);
create index on ids.criterion_score(assessment_event_id, context_assessment_type_id, context_rubric_version);
create index on ids.criterion_score(criterion_id, context_assessment_type_id, context_rubric_version, context_score_ceiling);
create index on ids.goal_review(goal_id, context_section_key);

-- Definition/scoring columns are immutable once used. Provenance is not definition.
create or replace function ids.protect_used_rubric() returns trigger
language plpgsql security invoker set search_path = pg_catalog as $$
begin
  if row(new.criterion_id, new.assessment_type_id, new.rubric_version, new.criterion_number,
         new.criterion_name, new.criterion_description, new.reference_scale, new.maximum_score,
         new.display_order, new.section, new.weight)
     is distinct from
     row(old.criterion_id, old.assessment_type_id, old.rubric_version, old.criterion_number,
         old.criterion_name, old.criterion_description, old.reference_scale, old.maximum_score,
         old.display_order, old.section, old.weight) then
    -- The remaining existence check needs a fresh snapshot after waiting on a writer.
    if current_setting('transaction_isolation') <> 'read committed' then
      raise exception using errcode = '0A000', message = 'rubric_definition_update_requires_read_committed';
    end if;
    if exists (select 1 from ids.criterion_score where criterion_id = old.criterion_id) then
      raise exception using errcode = '23514', message = 'used_criterion_definition_is_immutable';
    end if;
  end if;
  return new;
end;
$$;

create or replace view ids.enrolment_fee_summary with (security_invoker = true) as
with obligations as (
  select enrolment_id, sum(amount_due) as scheduled_net_due from ids.fee_instalment group by enrolment_id
), transactions as (
  select enrolment_id,
    sum(case when payment_type_id = 'payment_type.PAYMENT' then amount else -amount end) as net_paid,
    max(payment_date) filter (where payment_type_id = 'payment_type.PAYMENT') as last_payment_date
  from ids.fee_payment group by enrolment_id
)
select e.enrolment_id, e.total_fee_amount as source_gross_fee,
  e.supported_subsidy_amount as source_subsidy, o.scheduled_net_due,
  coalesce(t.net_paid, 0) as net_paid,
  o.scheduled_net_due - coalesce(t.net_paid, 0) as balance,
  case when o.scheduled_net_due is null then null
    else greatest(coalesce(t.net_paid, 0) - o.scheduled_net_due, 0) end as credit,
  t.last_payment_date
from ids.enrolment e left join obligations o using (enrolment_id)
left join transactions t using (enrolment_id);

-- Drop nonunique indexes whose keys are already a leading prefix of a unique key.
-- Only ordinary valid unqualified-column B-tree indexes with identical key options.
do $$
declare r record;
begin
  for r in
    select ni.nspname, ci.relname from pg_index i
    join pg_class ci on ci.oid = i.indexrelid
    join pg_namespace ni on ni.oid = ci.relnamespace
    where ni.nspname in ('ids','ids_import') and not i.indisunique
      and i.indisvalid and i.indpred is null and i.indexprs is null
      and exists (
        select 1 from pg_index u join pg_class cu on cu.oid = u.indexrelid
        where u.indrelid = i.indrelid and u.indisunique and u.indisvalid
          and u.indpred is null and u.indexprs is null and cu.relam = ci.relam
          and u.indnkeyatts >= i.indnkeyatts
          and not exists (select 1 from generate_series(0,i.indnkeyatts-1) k
            where i.indkey[k] <> u.indkey[k] or i.indclass[k] <> u.indclass[k]
               or i.indcollation[k] <> u.indcollation[k] or i.indoption[k] <> u.indoption[k])
      )
  loop
    execute format('drop index %I.%I', r.nspname, r.relname);
  end loop;
end;
$$;
-- New functions remain private; existing tables retain RLS and zero policies.
revoke all on all tables in schema ids, ids_import from public, anon, authenticated, service_role;
revoke all on all sequences in schema ids, ids_import from public, anon, authenticated, service_role;
revoke all on all functions in schema ids, ids_import from public, anon, authenticated, service_role;
commit;
