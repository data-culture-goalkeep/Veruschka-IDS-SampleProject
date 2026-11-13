-- Stage 3 review only. No hosted application is authorized.
-- Source timestamps are interpreted as Asia/Kolkata by the future loader.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
create schema ids;
create schema ids_import;
revoke all on schema ids from public, anon, authenticated, service_role;
alter default privileges in schema ids revoke all on tables from public, anon, authenticated, service_role;
alter default privileges in schema ids revoke all on sequences from public, anon, authenticated, service_role;
alter default privileges in schema ids revoke all on functions from public, anon, authenticated, service_role;
revoke all on schema ids_import from public, anon, authenticated, service_role;
alter default privileges in schema ids_import revoke all on tables from public, anon, authenticated, service_role;
alter default privileges in schema ids_import revoke all on sequences from public, anon, authenticated, service_role;
alter default privileges in schema ids_import revoke all on functions from public, anon, authenticated, service_role;

create table ids_import.import_run (
  import_run_id uuid primary key default gen_random_uuid(),
  project_ref text not null check (project_ref = 'uzofrrrtwqjmtytrbqfr'),
  source_file_id text not null,
  approved_scope jsonb not null,
  source_timezone text not null check (source_timezone = 'Asia/Kolkata'),
  source_manifest jsonb not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null check (status in ('pending','running','completed','failed','uncertain'))
);
create table ids_import.import_chunk (
  import_chunk_id uuid primary key default gen_random_uuid(),
  import_run_id uuid not null references ids_import.import_run,
  source_sheet_id bigint not null,
  first_row integer not null check (first_row >= 3),
  last_row integer not null check (last_row >= first_row),
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  status text not null check (status in ('pending','committed','failed','uncertain')),
  committed_at timestamptz,
  unique (import_run_id, source_sheet_id, first_row, last_row),
  unique (import_chunk_id, import_run_id)
);
create table ids_import.source_row (
  source_row_id uuid primary key default gen_random_uuid(),
  import_run_id uuid not null references ids_import.import_run,
  import_chunk_id uuid,
  source_file_id text not null,
  source_sheet_id bigint not null,
  source_tab text not null,
  original_row integer not null check (original_row >= 3),
  raw_values jsonb not null,
  raw_formatted_values jsonb,
  raw_sha256 text not null check (raw_sha256 ~ '^[0-9a-f]{64}$'),
  disposition text check (disposition in ('loaded','staging_only','quarantined')),
  target_table text,
  target_record_key text,
  recorded_at timestamptz not null default now(),
  unique (import_run_id, source_sheet_id, original_row),
  foreign key (import_chunk_id, import_run_id)
    references ids_import.import_chunk(import_chunk_id, import_run_id),
  check (disposition is distinct from 'loaded' or
         (target_table is not null and target_record_key is not null))
);
create table ids_import.validation_issue (
  validation_issue_id uuid primary key default gen_random_uuid(),
  source_row_id uuid not null references ids_import.source_row,
  severity text not null check (severity in ('warning','error')),
  reason_code text not null,
  reason text not null,
  recorded_at timestamptz not null default now(),
  unique (source_row_id, reason_code)
);
create index import_chunk_run_idx on ids_import.import_chunk(import_run_id);
create index source_row_chunk_run_idx on ids_import.source_row(import_chunk_id, import_run_id);
create index source_row_run_idx on ids_import.source_row(import_run_id);
create index validation_issue_source_idx on ids_import.validation_issue(source_row_id);


-- Source tab: 1.Mobilisation Lead; 280 inspected rows.
create table ids.mobilisation_lead (
  candidate_id text primary key,
  learner_id text,
  lead_date date,
  candidate_name text,
  mobile text,
  gender text,
  age integer,
  community_area text,
  source_type_id text,
  programme_interested_id text,
  education_level_id text,
  employment_status_id text,
  mobilisation_activity text,
  current_status_id text,
  follow_up_date date,
  assigned_associate_id text,
  consent_collected boolean,
  remarks text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint mobilisation_lead_uq_1 unique (learner_id),
  check (split_part(source_type_id, '.', 1) = 'source_type'),
  check (split_part(programme_interested_id, '.', 1) = 'programme'),
  check (split_part(education_level_id, '.', 1) = 'education_level'),
  check (split_part(employment_status_id, '.', 1) = 'employment_status'),
  check (split_part(current_status_id, '.', 1) = 'lead_status')
);

-- Source tab: 2.Lead Follow-up; 560 inspected rows.
create table ids.lead_follow_up (
  followup_id text primary key,
  lead_id text not null,
  follow_up_date date,
  stage_id text,
  follow_up_type_id text,
  channel_id text,
  reason text,
  outcome_id text,
  next_follow_up_date date,
  priority_id text,
  owner_staff_id text,
  closure_status_id text,
  notes text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  check (split_part(stage_id, '.', 1) = 'lead_stage'),
  check (split_part(follow_up_type_id, '.', 1) = 'follow_up_type'),
  check (split_part(channel_id, '.', 1) = 'channel'),
  check (split_part(outcome_id, '.', 1) = 'follow_up_outcome'),
  check (split_part(priority_id, '.', 1) = 'priority'),
  check (split_part(closure_status_id, '.', 1) = 'closure_status')
);

-- Source tab: 3.Mobilisation Activity; 810 inspected rows.
create table ids.mobilisation_activity (
  activity_id text primary key,
  activity_date date,
  associate_staff_id text,
  activity_type_id text,
  partner_organisation_id text,
  location text,
  time_slot text,
  contact_person text,
  contact_number text,
  channel_id text,
  target_outreach integer,
  participants_reached integer,
  leads_generated integer,
  enrolments_expected integer,
  followups_completed integer,
  key_issues text,
  next_action text,
  next_follow_up_date date,
  status_id text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  check (split_part(activity_type_id, '.', 1) = 'activity_type'),
  check (split_part(channel_id, '.', 1) = 'channel'),
  check (split_part(status_id, '.', 1) = 'activity_status')
);

-- Source tab: 4.Partner Organisation; 12 inspected rows.
create table ids.partner_organisation (
  partner_organisation_id text primary key,
  organisation_name text,
  partnership_status_id text,
  mou_signed_date date,
  contact_person text,
  contact_email text,
  contact_phone text,
  notes text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  check (split_part(partnership_status_id, '.', 1) = 'partnership_status')
);

-- Source tab: 5.Monthly Target; 162 inspected rows.
create table ids.monthly_target (
  target_id text primary key,
  staff_id text not null,
  month date not null,
  contact_target integer,
  lead_target integer,
  enrolment_target integer,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint monthly_target_uq_1 unique (staff_id, month),
  constraint monthly_target_check_1 check (extract(day from month) = 1)
);

-- Source tab: 6.Report & Meeting Log; 216 inspected rows.
create table ids.report_meeting_log (
  log_id text primary key,
  log_date date,
  type_id text,
  audience text,
  key_updates text,
  decisions_taken text,
  action_items text,
  owner_staff_id text,
  due_date date,
  status_id text,
  evidence_link text,
  remarks text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  check (split_part(type_id, '.', 1) = 'report_meeting_type'),
  check (split_part(status_id, '.', 1) = 'report_meeting_status')
);

-- Source tab: 7.Learner Profile; 215 inspected rows.
create table ids.learner_profile (
  learner_id text primary key,
  registration_no text,
  first_name text,
  middle_name text,
  last_name text,
  date_of_birth date,
  gender text,
  address text,
  state text,
  neighbourhood text,
  district_city text,
  pin_code text,
  email text,
  qualification_id text,
  qualification_notes text,
  languages_known text,
  family_member_count integer,
  residence_type_id text,
  residence_ownership_id text,
  family_income_band_id text,
  monthly_rent numeric,
  per_capita_income numeric,
  apl_bpl text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  check (split_part(qualification_id, '.', 1) = 'qualification'),
  check (split_part(residence_type_id, '.', 1) = 'residence_type'),
  check (split_part(residence_ownership_id, '.', 1) = 'residence_ownership'),
  check (split_part(family_income_band_id, '.', 1) = 'family_income_band')
);

-- Source tab: 8.Family Contact; 286 inspected rows.
create table ids.family_contact (
  contact_id text primary key,
  learner_id text not null,
  contact_name text,
  relationship_to_learner_id text,
  contact_role_id text,
  mobile text,
  email text,
  auth_user_id uuid,
  login_phone text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  check (split_part(relationship_to_learner_id, '.', 1) = 'relationship_to_learner'),
  check (split_part(contact_role_id, '.', 1) = 'contact_role')
);

-- Source tab: 9.Learner Sensitive Details; 215 inspected rows.
create table ids.learner_sensitive_details (
  learner_id text primary key,
  aadhaar_number text not null,
  pan_number text,
  diagnosis_disability_type text,
  disability_percent numeric,
  udid text,
  associated_medical_condition text,
  medication_details text,
  family_income_exact numeric,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint learner_sensitive_details_check_1 check (length(btrim(aadhaar_number)) > 0)
);

-- Source tab: 10.Batch; 20 inspected rows.
create table ids.batch (
  batch_id text primary key,
  financial_year text,
  centre_id text,
  center_type_id text,
  quarter text,
  batch_number integer,
  program_id text,
  shift_id text,
  planned_start_date date,
  planned_end_date date,
  actual_start_date date,
  actual_end_date date,
  is_active boolean,
  max_students integer,
  class_days text,
  default_start_time time,
  default_end_time time,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint batch_check_1 check (class_days ~ '^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)(, *(Mon|Tue|Wed|Thu|Fri|Sat|Sun))*$'),
  check (split_part(centre_id, '.', 1) = 'centre'),
  check (split_part(center_type_id, '.', 1) = 'centre_type'),
  check (split_part(program_id, '.', 1) = 'programme'),
  check (split_part(shift_id, '.', 1) = 'shift')
);

-- Source tab: 11.Enrolment; 220 inspected rows.
create table ids.enrolment (
  enrolment_id text primary key,
  learner_id text not null,
  batch_id text not null,
  enrolment_date date,
  status_id text,
  dropout_reason text,
  exit_date date,
  exit_outcome_id text,
  program_duration_weeks integer,
  source_type_id text,
  source_name text,
  sourcing_associate_id text,
  parents_meeting_relationship_id text,
  total_fee_amount numeric,
  supported_subsidy_amount numeric,
  id_proof_submitted boolean,
  education_proof_submitted boolean,
  photo_submitted boolean,
  consent_form_submitted boolean,
  document_remarks text,
  supporter_contact_id text,
  supporter_apron_date date,
  is_active boolean,
  programme_associate_staff_id text,
  enrolled_by_staff_id text,
  docs_provided boolean,
  orientation_scheduled_date date,
  orientation_attended boolean,
  programme_level_id text,
  consent_given boolean,
  consent_date date,
  graduation_notes text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint enrolment_uq_1 unique (learner_id, batch_id),
  check (split_part(status_id, '.', 1) = 'enrolment_status'),
  check (split_part(exit_outcome_id, '.', 1) = 'exit_outcome'),
  check (split_part(source_type_id, '.', 1) = 'source_type'),
  check (split_part(parents_meeting_relationship_id, '.', 1) = 'parents_meeting_relationship'),
  check (split_part(programme_level_id, '.', 1) = 'programme_level')
);

-- Source tab: 12.Fee Instalment; 660 inspected rows.
create table ids.fee_instalment (
  instalment_id text primary key,
  enrolment_id text not null,
  instalment_number integer not null,
  amount_due numeric not null,
  due_date date,
  remarks text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint fee_instalment_uq_1 unique (enrolment_id, instalment_number),
  constraint fee_instalment_check_1 check (amount_due >= 0),
  constraint fee_instalment_check_2 check (instalment_number > 0)
);

-- Source tab: 13.Fee Payment; 597 inspected rows.
create table ids.fee_payment (
  payment_id text primary key,
  enrolment_id text not null,
  payment_date date,
  amount numeric not null,
  payment_type_id text not null,
  payment_mode_id text,
  receipt_number text,
  received_by_staff_id text,
  remarks text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint fee_payment_check_1 check (amount > 0),
  check (split_part(payment_type_id, '.', 1) = 'payment_type'),
  check (split_part(payment_mode_id, '.', 1) = 'payment_mode')
);

-- Source tab: 14.Master Programme Schedule; 120 inspected rows.
create table ids.master_programme_schedule (
  master_programme_schedule_id text primary key,
  programme_id text not null,
  template_name text not null,
  week_number integer not null,
  session_number integer not null,
  session_type_id text,
  topic_id text,
  extra_topic_note text,
  assessment_type_id text,
  assessment_no text,
  home_programme text,
  notes text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint master_programme_schedule_uq_1 unique (template_name, programme_id, week_number, session_number),
  constraint master_programme_schedule_check_1 check (week_number > 0),
  constraint master_programme_schedule_check_2 check (session_number between 1 and 3),
  check (split_part(programme_id, '.', 1) = 'programme'),
  check (split_part(session_type_id, '.', 1) = 'session_type'),
  check (split_part(assessment_type_id, '.', 1) = 'assessment_type')
);

-- Source tab: 15.Standard Topic; 50 inspected rows.
create table ids.standard_topic (
  topic_id text primary key,
  session_type_id text,
  topic_name text,
  curriculum_strand_id text,
  sort_order integer,
  module_name text,
  topic_description text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  check (split_part(session_type_id, '.', 1) = 'session_type'),
  check (split_part(curriculum_strand_id, '.', 1) = 'curriculum_strand')
);

-- Source tab: 16.Batch Schedule; 1320 inspected rows.
create table ids.batch_schedule (
  batch_schedule_id text primary key,
  batch_id text not null,
  master_programme_schedule_id text,
  week_number integer not null,
  session_number integer not null,
  planned_session_date date,
  actual_session_date date,
  session_type_id text,
  topic_id text,
  facilitator_staff_id text,
  extra_topic_note text,
  other_faculty_note text,
  assessment_type_id text,
  assessment_no text,
  home_programme text,
  holiday_note text,
  start_time time,
  end_time time,
  delivery_status_id text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint batch_schedule_uq_1 unique (batch_id, week_number, session_number),
  constraint batch_schedule_check_1 check (week_number > 0),
  constraint batch_schedule_check_2 check (session_number between 1 and 3),
  check (split_part(session_type_id, '.', 1) = 'session_type'),
  check (split_part(assessment_type_id, '.', 1) = 'assessment_type'),
  check (split_part(delivery_status_id, '.', 1) = 'delivery_status')
);

-- Source tab: 17.Learner Session Log; 1620 inspected rows.
create table ids.learner_session_log (
  learner_session_log_id text primary key,
  enrolment_id text not null,
  batch_schedule_id text not null,
  attendance_mark text,
  home_practice_status_id text,
  journal_status_id text,
  notes text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  attendance_reference_id text generated always as (case when attendance_mark is null then null else 'attendance.' || attendance_mark end) stored,
  constraint learner_session_log_uq_1 unique (enrolment_id, batch_schedule_id),
  check (split_part(home_practice_status_id, '.', 1) = 'home_practice_status'),
  check (split_part(journal_status_id, '.', 1) = 'journal_status')
);

-- Source tab: 18.Goal; 0 inspected rows.
create table ids.goal (
  goal_id text primary key,
  enrolment_id text not null,
  goal_number integer not null,
  goal_section_id text,
  responsible_contact_id text,
  plan_date date,
  focus_area text,
  skill_module text,
  goal_statement text,
  long_term_goal text,
  tools_and_strategies text,
  family_involvement_action text,
  involvement_area text,
  plan_of_action text,
  goal_status_id text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint goal_uq_1 unique (enrolment_id, goal_number),
  constraint goal_check_1 check (goal_number > 0),
  check (split_part(goal_section_id, '.', 1) = 'goal_section'),
  check (split_part(goal_status_id, '.', 1) = 'goal_status')
);

-- Source tab: 19.Goal Review; 0 inspected rows.
create table ids.goal_review (
  goal_review_id text primary key,
  goal_id text not null,
  milestone_week integer not null,
  review_date date,
  faculty_rating_id text,
  family_rating_id text,
  skill_transfer text,
  status_id text,
  what_is_working text,
  what_needs_change text,
  family_inputs text,
  faculty_remarks text,
  remarks_or_evidence text,
  readiness_indicators text,
  next_steps text,
  ideal_seed_pathway text,
  ffm_ffi_date date,
  faculty_rating_score numeric,
  family_rating_score numeric,
  ideal_seed_pathway_other text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint goal_review_uq_1 unique (goal_id, milestone_week),
  constraint goal_review_check_1 check (milestone_week in (4,8,12,16,20,24)),
  constraint goal_review_check_2 check (ideal_seed_pathway is distinct from 'seed_pathway.OTHER' or nullif(btrim(ideal_seed_pathway_other), '') is not null),
  check (split_part(faculty_rating_id, '.', 1) = 'faculty_rating'),
  check (split_part(family_rating_id, '.', 1) = 'family_rating'),
  check (split_part(skill_transfer, '.', 1) = 'skill_transfer'),
  check (split_part(status_id, '.', 1) = 'goal_review_status'),
  check (split_part(ideal_seed_pathway, '.', 1) = 'seed_pathway')
);

-- Source tab: 20.Assessment Event; 0 inspected rows.
create table ids.assessment_event (
  assessment_event_id text primary key,
  enrolment_id text not null,
  batch_schedule_id text,
  assessment_type_id text not null,
  rubric_version text not null,
  assessment_no text,
  assessment_date date,
  topic_or_dish text,
  assessor_staff_id text,
  supported_by_contact_id text,
  result_status_id text,
  module_name text,
  remarks text,
  iq_value text,
  height_value numeric,
  weight_value numeric,
  assessment_stage_id text,
  measure_method_id text,
  signed_at timestamptz,
  approved_by_staff_id text,
  approved_at timestamptz,
  parents_goals text,
  achievable_goals text,
  implementation_plan text,
  recommendations text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  check (split_part(assessment_type_id, '.', 1) = 'assessment_type'),
  check (split_part(result_status_id, '.', 1) = 'assessment_result_status'),
  check (split_part(assessment_stage_id, '.', 1) = 'assessment_stage'),
  check (split_part(measure_method_id, '.', 1) = 'measure_method')
);

-- Source tab: 21.Criterion Catalogue; 210 inspected rows.
create table ids.criterion_catalogue (
  criterion_id text primary key,
  assessment_type_id text not null,
  rubric_version text not null,
  criterion_number integer not null,
  criterion_name text not null,
  criterion_description text,
  reference_scale text,
  maximum_score numeric,
  display_order integer,
  section text,
  weight numeric,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint criterion_catalogue_uq_1 unique (assessment_type_id, rubric_version, criterion_name),
  check (split_part(assessment_type_id, '.', 1) = 'assessment_type')
);

-- Source tab: 22.Criterion Score; 0 inspected rows.
create table ids.criterion_score (
  criterion_score_id text primary key,
  assessment_event_id text not null,
  criterion_id text not null,
  score_value numeric,
  rating_id text,
  remark_text text,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint criterion_score_uq_1 unique (assessment_event_id, criterion_id),
  constraint criterion_score_check_1 check (score_value >= 0),
  check (split_part(rating_id, '.', 1) = 'criterion_rating')
);

-- Source tab: 23.Staff; 20 inspected rows.
create table ids.staff (
  staff_id text primary key,
  auth_user_id uuid,
  full_name text,
  email text,
  job_title text,
  staff_type_id text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint staff_uq_1 unique (auth_user_id),
  check (split_part(staff_type_id, '.', 1) = 'staff_type')
);

-- Source tab: 24.Reference List; 154 inspected rows.
create table ids.reference_list (
  reference_value_id text primary key,
  list_name text not null,
  display_label text not null,
  sort_order integer,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  created_by text,
  updated_by text,
  source_row_id uuid,
  constraint reference_list_check_1 check (split_part(reference_value_id, '.', 1) = list_name),
  constraint reference_list_check_2 check (position('.' in reference_value_id) > 1)
);
alter table ids.mobilisation_lead add foreign key (learner_id) references ids.learner_profile(learner_id) deferrable initially immediate;
create index on ids.mobilisation_lead (learner_id);
alter table ids.mobilisation_lead add foreign key (source_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.mobilisation_lead (source_type_id);
alter table ids.mobilisation_lead add foreign key (programme_interested_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.mobilisation_lead (programme_interested_id);
alter table ids.mobilisation_lead add foreign key (education_level_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.mobilisation_lead (education_level_id);
alter table ids.mobilisation_lead add foreign key (employment_status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.mobilisation_lead (employment_status_id);
alter table ids.mobilisation_lead add foreign key (current_status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.mobilisation_lead (current_status_id);
alter table ids.mobilisation_lead add foreign key (assigned_associate_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.mobilisation_lead (assigned_associate_id);
alter table ids.mobilisation_lead add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.mobilisation_lead (created_by);
alter table ids.mobilisation_lead add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.mobilisation_lead (updated_by);
alter table ids.mobilisation_lead add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.mobilisation_lead (source_row_id);
alter table ids.lead_follow_up add foreign key (lead_id) references ids.mobilisation_lead(candidate_id) deferrable initially immediate;
create index on ids.lead_follow_up (lead_id);
alter table ids.lead_follow_up add foreign key (stage_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.lead_follow_up (stage_id);
alter table ids.lead_follow_up add foreign key (follow_up_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.lead_follow_up (follow_up_type_id);
alter table ids.lead_follow_up add foreign key (channel_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.lead_follow_up (channel_id);
alter table ids.lead_follow_up add foreign key (outcome_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.lead_follow_up (outcome_id);
alter table ids.lead_follow_up add foreign key (priority_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.lead_follow_up (priority_id);
alter table ids.lead_follow_up add foreign key (owner_staff_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.lead_follow_up (owner_staff_id);
alter table ids.lead_follow_up add foreign key (closure_status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.lead_follow_up (closure_status_id);
alter table ids.lead_follow_up add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.lead_follow_up (created_by);
alter table ids.lead_follow_up add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.lead_follow_up (updated_by);
alter table ids.lead_follow_up add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.lead_follow_up (source_row_id);
alter table ids.mobilisation_activity add foreign key (associate_staff_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.mobilisation_activity (associate_staff_id);
alter table ids.mobilisation_activity add foreign key (activity_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.mobilisation_activity (activity_type_id);
alter table ids.mobilisation_activity add foreign key (partner_organisation_id) references ids.partner_organisation(partner_organisation_id) deferrable initially immediate;
create index on ids.mobilisation_activity (partner_organisation_id);
alter table ids.mobilisation_activity add foreign key (channel_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.mobilisation_activity (channel_id);
alter table ids.mobilisation_activity add foreign key (status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.mobilisation_activity (status_id);
alter table ids.mobilisation_activity add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.mobilisation_activity (created_by);
alter table ids.mobilisation_activity add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.mobilisation_activity (updated_by);
alter table ids.mobilisation_activity add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.mobilisation_activity (source_row_id);
alter table ids.partner_organisation add foreign key (partnership_status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.partner_organisation (partnership_status_id);
alter table ids.partner_organisation add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.partner_organisation (created_by);
alter table ids.partner_organisation add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.partner_organisation (updated_by);
alter table ids.partner_organisation add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.partner_organisation (source_row_id);
alter table ids.monthly_target add foreign key (staff_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.monthly_target (staff_id);
alter table ids.monthly_target add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.monthly_target (created_by);
alter table ids.monthly_target add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.monthly_target (updated_by);
alter table ids.monthly_target add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.monthly_target (source_row_id);
alter table ids.report_meeting_log add foreign key (type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.report_meeting_log (type_id);
alter table ids.report_meeting_log add foreign key (owner_staff_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.report_meeting_log (owner_staff_id);
alter table ids.report_meeting_log add foreign key (status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.report_meeting_log (status_id);
alter table ids.report_meeting_log add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.report_meeting_log (created_by);
alter table ids.report_meeting_log add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.report_meeting_log (updated_by);
alter table ids.report_meeting_log add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.report_meeting_log (source_row_id);
alter table ids.learner_profile add foreign key (qualification_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.learner_profile (qualification_id);
alter table ids.learner_profile add foreign key (residence_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.learner_profile (residence_type_id);
alter table ids.learner_profile add foreign key (residence_ownership_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.learner_profile (residence_ownership_id);
alter table ids.learner_profile add foreign key (family_income_band_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.learner_profile (family_income_band_id);
alter table ids.learner_profile add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.learner_profile (created_by);
alter table ids.learner_profile add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.learner_profile (updated_by);
alter table ids.learner_profile add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.learner_profile (source_row_id);
alter table ids.family_contact add foreign key (learner_id) references ids.learner_profile(learner_id) deferrable initially immediate;
create index on ids.family_contact (learner_id);
alter table ids.family_contact add foreign key (relationship_to_learner_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.family_contact (relationship_to_learner_id);
alter table ids.family_contact add foreign key (contact_role_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.family_contact (contact_role_id);
alter table ids.family_contact add foreign key (auth_user_id) references auth.users(id) deferrable initially immediate;
create index on ids.family_contact (auth_user_id);
alter table ids.family_contact add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.family_contact (created_by);
alter table ids.family_contact add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.family_contact (updated_by);
alter table ids.family_contact add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.family_contact (source_row_id);
alter table ids.learner_sensitive_details add foreign key (learner_id) references ids.learner_profile(learner_id) deferrable initially immediate;
create index on ids.learner_sensitive_details (learner_id);
alter table ids.learner_sensitive_details add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.learner_sensitive_details (created_by);
alter table ids.learner_sensitive_details add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.learner_sensitive_details (updated_by);
alter table ids.learner_sensitive_details add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.learner_sensitive_details (source_row_id);
alter table ids.batch add foreign key (centre_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.batch (centre_id);
alter table ids.batch add foreign key (center_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.batch (center_type_id);
alter table ids.batch add foreign key (program_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.batch (program_id);
alter table ids.batch add foreign key (shift_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.batch (shift_id);
alter table ids.batch add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.batch (created_by);
alter table ids.batch add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.batch (updated_by);
alter table ids.batch add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.batch (source_row_id);
alter table ids.enrolment add foreign key (learner_id) references ids.learner_profile(learner_id) deferrable initially immediate;
create index on ids.enrolment (learner_id);
alter table ids.enrolment add foreign key (batch_id) references ids.batch(batch_id) deferrable initially immediate;
create index on ids.enrolment (batch_id);
alter table ids.enrolment add foreign key (status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.enrolment (status_id);
alter table ids.enrolment add foreign key (exit_outcome_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.enrolment (exit_outcome_id);
alter table ids.enrolment add foreign key (source_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.enrolment (source_type_id);
alter table ids.enrolment add foreign key (sourcing_associate_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.enrolment (sourcing_associate_id);
alter table ids.enrolment add foreign key (parents_meeting_relationship_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.enrolment (parents_meeting_relationship_id);
alter table ids.enrolment add foreign key (supporter_contact_id) references ids.family_contact(contact_id) deferrable initially immediate;
create index on ids.enrolment (supporter_contact_id);
alter table ids.enrolment add foreign key (programme_associate_staff_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.enrolment (programme_associate_staff_id);
alter table ids.enrolment add foreign key (enrolled_by_staff_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.enrolment (enrolled_by_staff_id);
alter table ids.enrolment add foreign key (programme_level_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.enrolment (programme_level_id);
alter table ids.enrolment add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.enrolment (created_by);
alter table ids.enrolment add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.enrolment (updated_by);
alter table ids.enrolment add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.enrolment (source_row_id);
alter table ids.fee_instalment add foreign key (enrolment_id) references ids.enrolment(enrolment_id) deferrable initially immediate;
create index on ids.fee_instalment (enrolment_id);
alter table ids.fee_instalment add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.fee_instalment (created_by);
alter table ids.fee_instalment add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.fee_instalment (updated_by);
alter table ids.fee_instalment add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.fee_instalment (source_row_id);
alter table ids.fee_payment add foreign key (enrolment_id) references ids.enrolment(enrolment_id) deferrable initially immediate;
create index on ids.fee_payment (enrolment_id);
alter table ids.fee_payment add foreign key (payment_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.fee_payment (payment_type_id);
alter table ids.fee_payment add foreign key (payment_mode_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.fee_payment (payment_mode_id);
alter table ids.fee_payment add foreign key (received_by_staff_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.fee_payment (received_by_staff_id);
alter table ids.fee_payment add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.fee_payment (created_by);
alter table ids.fee_payment add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.fee_payment (updated_by);
alter table ids.fee_payment add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.fee_payment (source_row_id);
alter table ids.master_programme_schedule add foreign key (programme_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.master_programme_schedule (programme_id);
alter table ids.master_programme_schedule add foreign key (session_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.master_programme_schedule (session_type_id);
alter table ids.master_programme_schedule add foreign key (topic_id) references ids.standard_topic(topic_id) deferrable initially immediate;
create index on ids.master_programme_schedule (topic_id);
alter table ids.master_programme_schedule add foreign key (assessment_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.master_programme_schedule (assessment_type_id);
alter table ids.master_programme_schedule add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.master_programme_schedule (created_by);
alter table ids.master_programme_schedule add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.master_programme_schedule (updated_by);
alter table ids.master_programme_schedule add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.master_programme_schedule (source_row_id);
alter table ids.standard_topic add foreign key (session_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.standard_topic (session_type_id);
alter table ids.standard_topic add foreign key (curriculum_strand_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.standard_topic (curriculum_strand_id);
alter table ids.standard_topic add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.standard_topic (created_by);
alter table ids.standard_topic add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.standard_topic (updated_by);
alter table ids.standard_topic add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.standard_topic (source_row_id);
alter table ids.batch_schedule add foreign key (batch_id) references ids.batch(batch_id) deferrable initially immediate;
create index on ids.batch_schedule (batch_id);
alter table ids.batch_schedule add foreign key (master_programme_schedule_id) references ids.master_programme_schedule(master_programme_schedule_id) deferrable initially immediate;
create index on ids.batch_schedule (master_programme_schedule_id);
alter table ids.batch_schedule add foreign key (session_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.batch_schedule (session_type_id);
alter table ids.batch_schedule add foreign key (topic_id) references ids.standard_topic(topic_id) deferrable initially immediate;
create index on ids.batch_schedule (topic_id);
alter table ids.batch_schedule add foreign key (facilitator_staff_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.batch_schedule (facilitator_staff_id);
alter table ids.batch_schedule add foreign key (assessment_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.batch_schedule (assessment_type_id);
alter table ids.batch_schedule add foreign key (delivery_status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.batch_schedule (delivery_status_id);
alter table ids.batch_schedule add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.batch_schedule (created_by);
alter table ids.batch_schedule add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.batch_schedule (updated_by);
alter table ids.batch_schedule add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.batch_schedule (source_row_id);
alter table ids.learner_session_log add foreign key (enrolment_id) references ids.enrolment(enrolment_id) deferrable initially immediate;
create index on ids.learner_session_log (enrolment_id);
alter table ids.learner_session_log add foreign key (batch_schedule_id) references ids.batch_schedule(batch_schedule_id) deferrable initially immediate;
create index on ids.learner_session_log (batch_schedule_id);
alter table ids.learner_session_log add foreign key (home_practice_status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.learner_session_log (home_practice_status_id);
alter table ids.learner_session_log add foreign key (journal_status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.learner_session_log (journal_status_id);
alter table ids.learner_session_log add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.learner_session_log (created_by);
alter table ids.learner_session_log add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.learner_session_log (updated_by);
alter table ids.learner_session_log add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.learner_session_log (source_row_id);
alter table ids.goal add foreign key (enrolment_id) references ids.enrolment(enrolment_id) deferrable initially immediate;
create index on ids.goal (enrolment_id);
alter table ids.goal add foreign key (goal_section_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.goal (goal_section_id);
alter table ids.goal add foreign key (responsible_contact_id) references ids.family_contact(contact_id) deferrable initially immediate;
create index on ids.goal (responsible_contact_id);
alter table ids.goal add foreign key (goal_status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.goal (goal_status_id);
alter table ids.goal add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.goal (created_by);
alter table ids.goal add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.goal (updated_by);
alter table ids.goal add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.goal (source_row_id);
alter table ids.goal_review add foreign key (goal_id) references ids.goal(goal_id) deferrable initially immediate;
create index on ids.goal_review (goal_id);
alter table ids.goal_review add foreign key (faculty_rating_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.goal_review (faculty_rating_id);
alter table ids.goal_review add foreign key (family_rating_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.goal_review (family_rating_id);
alter table ids.goal_review add foreign key (skill_transfer) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.goal_review (skill_transfer);
alter table ids.goal_review add foreign key (status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.goal_review (status_id);
alter table ids.goal_review add foreign key (ideal_seed_pathway) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.goal_review (ideal_seed_pathway);
alter table ids.goal_review add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.goal_review (created_by);
alter table ids.goal_review add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.goal_review (updated_by);
alter table ids.goal_review add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.goal_review (source_row_id);
alter table ids.assessment_event add foreign key (enrolment_id) references ids.enrolment(enrolment_id) deferrable initially immediate;
create index on ids.assessment_event (enrolment_id);
alter table ids.assessment_event add foreign key (batch_schedule_id) references ids.batch_schedule(batch_schedule_id) deferrable initially immediate;
create index on ids.assessment_event (batch_schedule_id);
alter table ids.assessment_event add foreign key (assessment_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.assessment_event (assessment_type_id);
alter table ids.assessment_event add foreign key (assessor_staff_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.assessment_event (assessor_staff_id);
alter table ids.assessment_event add foreign key (supported_by_contact_id) references ids.family_contact(contact_id) deferrable initially immediate;
create index on ids.assessment_event (supported_by_contact_id);
alter table ids.assessment_event add foreign key (result_status_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.assessment_event (result_status_id);
alter table ids.assessment_event add foreign key (assessment_stage_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.assessment_event (assessment_stage_id);
alter table ids.assessment_event add foreign key (measure_method_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.assessment_event (measure_method_id);
alter table ids.assessment_event add foreign key (approved_by_staff_id) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.assessment_event (approved_by_staff_id);
alter table ids.assessment_event add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.assessment_event (created_by);
alter table ids.assessment_event add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.assessment_event (updated_by);
alter table ids.assessment_event add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.assessment_event (source_row_id);
alter table ids.criterion_catalogue add foreign key (assessment_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.criterion_catalogue (assessment_type_id);
alter table ids.criterion_catalogue add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.criterion_catalogue (created_by);
alter table ids.criterion_catalogue add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.criterion_catalogue (updated_by);
alter table ids.criterion_catalogue add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.criterion_catalogue (source_row_id);
alter table ids.criterion_score add foreign key (assessment_event_id) references ids.assessment_event(assessment_event_id) deferrable initially immediate;
create index on ids.criterion_score (assessment_event_id);
alter table ids.criterion_score add foreign key (criterion_id) references ids.criterion_catalogue(criterion_id) deferrable initially immediate;
create index on ids.criterion_score (criterion_id);
alter table ids.criterion_score add foreign key (rating_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.criterion_score (rating_id);
alter table ids.criterion_score add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.criterion_score (created_by);
alter table ids.criterion_score add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.criterion_score (updated_by);
alter table ids.criterion_score add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.criterion_score (source_row_id);
alter table ids.staff add foreign key (auth_user_id) references auth.users(id) deferrable initially immediate;
create index on ids.staff (auth_user_id);
alter table ids.staff add foreign key (staff_type_id) references ids.reference_list(reference_value_id) deferrable initially immediate;
create index on ids.staff (staff_type_id);
alter table ids.staff add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.staff (created_by);
alter table ids.staff add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.staff (updated_by);
alter table ids.staff add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.staff (source_row_id);
alter table ids.reference_list add foreign key (created_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.reference_list (created_by);
alter table ids.reference_list add foreign key (updated_by) references ids.staff(staff_id) deferrable initially immediate;
create index on ids.reference_list (updated_by);
alter table ids.reference_list add foreign key (source_row_id) references ids_import.source_row(source_row_id);
create index on ids.reference_list (source_row_id);
alter table ids.learner_session_log add foreign key (attendance_reference_id) references ids.reference_list(reference_value_id);
create index on ids.learner_session_log(attendance_reference_id);
-- Functions are SECURITY INVOKER and private; execution grants are revoked below.
-- Child checks lock relevant parents so concurrent parent changes cannot invalidate them.
create function ids.check_row_context() returns trigger
language plpgsql security invoker set search_path = pg_catalog as $$
declare
  e ids.enrolment%rowtype;
  s ids.batch_schedule%rowtype;
  c ids.family_contact%rowtype;
  g ids.goal%rowtype;
  ev ids.assessment_event%rowtype;
  cr ids.criterion_catalogue%rowtype;
  lower_bound numeric;
  upper_bound numeric;
begin
  if tg_table_name = 'enrolment' then
    if new.supporter_contact_id is not null then
      select * into strict c from ids.family_contact where contact_id = new.supporter_contact_id for share;
      if c.learner_id <> new.learner_id then
        raise exception using errcode = '23514', message = 'supporter_contact_learner_mismatch';
      end if;
    end if;
  elsif tg_table_name in ('goal', 'assessment_event', 'learner_session_log') then
    select * into strict e from ids.enrolment where enrolment_id = new.enrolment_id for share;
    if tg_table_name = 'goal' then
      if new.responsible_contact_id is not null then
        select * into strict c from ids.family_contact where contact_id = new.responsible_contact_id for share;
        if c.learner_id <> e.learner_id then
          raise exception using errcode = '23514', message = 'responsible_contact_learner_mismatch';
        end if;
      end if;
      -- Goal delivery is restricted to ILS, while retaining SEED as a permitted reference value.
      perform 1 from ids.batch where batch_id = e.batch_id and program_id = 'programme.ILS' for share;
      if not found then
        raise exception using errcode = '23514', message = 'goal_requires_ils_enrolment';
      end if;
    else
      if new.batch_schedule_id is not null then
        select * into strict s from ids.batch_schedule where batch_schedule_id = new.batch_schedule_id for share;
        if s.batch_id <> e.batch_id then
          raise exception using errcode = '23514', message = 'session_enrolment_batch_mismatch';
        end if;
      end if;
      if tg_table_name = 'assessment_event' then
        if new.supported_by_contact_id is not null then
          select * into strict c from ids.family_contact where contact_id = new.supported_by_contact_id for share;
          if c.learner_id <> e.learner_id then
            raise exception using errcode = '23514', message = 'assessment_contact_learner_mismatch';
          end if;
        end if;
      end if;
    end if;
  elsif tg_table_name = 'criterion_score' then
    select * into strict ev from ids.assessment_event where assessment_event_id = new.assessment_event_id for share;
    select * into strict cr from ids.criterion_catalogue where criterion_id = new.criterion_id for share;
    if (ev.assessment_type_id, ev.rubric_version) is distinct from (cr.assessment_type_id, cr.rubric_version) then
      raise exception using errcode = '23514', message = 'assessment_criterion_rubric_mismatch';
    end if;
    if new.score_value > cr.maximum_score then
      raise exception using errcode = '23514', message = 'criterion_score_exceeds_maximum';
    end if;
  elsif tg_table_name = 'goal_review' then
    select * into strict g from ids.goal where goal_id = new.goal_id for share;
    if g.goal_section_id = 'goal_section.SMART_GOALS' then
      lower_bound := 1; upper_bound := 4;
    elsif g.goal_section_id in ('goal_section.FUNCTIONAL_LEARNING','goal_section.HOSPITALITY') then
      lower_bound := 0; upper_bound := 3;
    end if;
    if (new.faculty_rating_score < lower_bound or new.faculty_rating_score > upper_bound)
       or (new.family_rating_score < lower_bound or new.family_rating_score > upper_bound) then
      raise exception using errcode = '23514', message = 'goal_review_score_out_of_section_range';
    end if;
  end if;
  return new;
exception when no_data_found then
  raise exception using errcode = '23503', message = 'required_context_parent_missing';
end;
$$;

create trigger check_enrolment_context before insert or update on ids.enrolment
for each row execute function ids.check_row_context();
create trigger check_goal_context before insert or update on ids.goal
for each row execute function ids.check_row_context();
create trigger check_assessment_context before insert or update on ids.assessment_event
for each row execute function ids.check_row_context();
create trigger check_session_log_context before insert or update on ids.learner_session_log
for each row execute function ids.check_row_context();
create trigger check_criterion_score_context before insert or update on ids.criterion_score
for each row execute function ids.check_row_context();
create trigger check_goal_review_context before insert or update on ids.goal_review
for each row execute function ids.check_row_context();

-- Parent updates are rare. A statement-level check also protects existing child rows.
-- No delivery/date or weekly-check constraints: approved source exceptions must remain loadable.
create function ids.check_parent_context() returns trigger
language plpgsql security invoker set search_path = pg_catalog as $$
begin
  if exists (
    select 1 from ids.enrolment e join ids.family_contact c on c.contact_id = e.supporter_contact_id
    where c.learner_id <> e.learner_id
  ) or exists (
    select 1 from ids.goal g join ids.enrolment e using (enrolment_id)
    join ids.family_contact c on c.contact_id = g.responsible_contact_id
    where c.learner_id <> e.learner_id
  ) or exists (
    select 1 from ids.assessment_event a join ids.enrolment e using (enrolment_id)
    join ids.family_contact c on c.contact_id = a.supported_by_contact_id
    where c.learner_id <> e.learner_id
  ) or exists (
    select 1 from ids.learner_session_log l join ids.enrolment e using (enrolment_id)
    join ids.batch_schedule s using (batch_schedule_id) where s.batch_id <> e.batch_id
  ) or exists (
    select 1 from ids.assessment_event a join ids.enrolment e using (enrolment_id)
    join ids.batch_schedule s using (batch_schedule_id) where s.batch_id <> e.batch_id
  ) or exists (
    select 1 from ids.criterion_score s join ids.assessment_event a using (assessment_event_id)
    join ids.criterion_catalogue c using (criterion_id)
    where (a.assessment_type_id, a.rubric_version) is distinct from (c.assessment_type_id, c.rubric_version)
       or s.score_value > c.maximum_score
  ) or exists (
    select 1 from ids.goal g join ids.enrolment e using (enrolment_id)
    join ids.batch b using (batch_id) where b.program_id is distinct from 'programme.ILS'
  ) or exists (
    select 1 from ids.goal_review r join ids.goal g using (goal_id)
    where (g.goal_section_id = 'goal_section.SMART_GOALS'
           and (r.faculty_rating_score not between 1 and 4 or r.family_rating_score not between 1 and 4))
       or (g.goal_section_id in ('goal_section.FUNCTIONAL_LEARNING','goal_section.HOSPITALITY')
           and (r.faculty_rating_score not between 0 and 3 or r.family_rating_score not between 0 and 3))
  ) then
    raise exception using errcode = '23514', message = 'parent_update_breaks_existing_context';
  end if;
  return null;
end;
$$;
create trigger check_contact_dependants after update of learner_id on ids.family_contact
for each statement execute function ids.check_parent_context();
create trigger check_enrolment_dependants after update of learner_id, batch_id on ids.enrolment
for each statement execute function ids.check_parent_context();
create trigger check_schedule_dependants after update of batch_id on ids.batch_schedule
for each statement execute function ids.check_parent_context();
create trigger check_goal_dependants after update of enrolment_id, goal_section_id on ids.goal
for each statement execute function ids.check_parent_context();
create trigger check_assessment_dependants after update of assessment_type_id, rubric_version on ids.assessment_event
for each statement execute function ids.check_parent_context();
create trigger check_batch_dependants after update of program_id on ids.batch
for each statement execute function ids.check_parent_context();

create function ids.protect_used_rubric() returns trigger
language plpgsql security invoker set search_path = pg_catalog as $$
begin
  if new is distinct from old and exists (
    select 1 from ids.criterion_score where criterion_id = old.criterion_id
  ) then
    raise exception using errcode = '23514', message = 'used_criterion_definition_is_immutable';
  end if;
  return new;
end;
$$;
create trigger protect_used_rubric before update on ids.criterion_catalogue
for each row execute function ids.protect_used_rubric();

create view ids.enrolment_fee_summary with (security_invoker = true) as
with obligations as (
  select enrolment_id, sum(amount_due) as scheduled_net_due from ids.fee_instalment group by enrolment_id
), transactions as (
  select enrolment_id,
    sum(case when payment_type_id = 'payment_type.PAYMENT' then amount else -amount end) as net_paid,
    max(payment_date) filter (where payment_type_id = 'payment_type.PAYMENT') as last_payment_date
  from ids.fee_payment group by enrolment_id
)
select e.enrolment_id, e.total_fee_amount as source_gross_fee,
  e.supported_subsidy_amount as source_subsidy,
  o.scheduled_net_due,
  coalesce(t.net_paid, 0) as net_paid,
  o.scheduled_net_due - coalesce(t.net_paid, 0) as balance,
  greatest(coalesce(t.net_paid, 0) - o.scheduled_net_due, 0) as credit,
  t.last_payment_date
from ids.enrolment e left join obligations o using (enrolment_id)
left join transactions t using (enrolment_id);

create view ids.fee_instalment_balance with (security_invoker = true) as
with ordered as (
  select i.*,
    coalesce(sum(amount_due) over (
      partition by enrolment_id order by due_date nulls last, instalment_number, instalment_id
      rows between unbounded preceding and 1 preceding), 0) as prior_due
  from ids.fee_instalment i
), allocated as (
  select i.*, greatest(least(i.amount_due, s.net_paid - i.prior_due), 0) as amount_paid
  from ordered i join ids.enrolment_fee_summary s using (enrolment_id)
)
select instalment_id, enrolment_id, instalment_number, due_date, amount_due,
  amount_paid, amount_due - amount_paid as amount_remaining,
  case when amount_paid >= amount_due then 'fee_status.PAID' else 'fee_status.PENDING' end as derived_status_id
from allocated;

-- Deploy-time exposure preflight is documented; this migration changes no API settings.
do $$
declare r record;
begin
  for r in select n.nspname, c.relname from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('ids','ids_import') and c.relkind = 'r'
  loop
    execute format('alter table %I.%I enable row level security', r.nspname, r.relname);
  end loop;
end;
$$;
revoke all on all tables in schema ids, ids_import from public, anon, authenticated, service_role;
revoke all on all sequences in schema ids, ids_import from public, anon, authenticated, service_role;
revoke all on all functions in schema ids, ids_import from public, anon, authenticated, service_role;
commit;
