# Field dictionary

Approved detailed diagram, with user decisions dated 2026-11-13. Source raw rows are never committed.

All tables also have nullable `source_row_id uuid → ids_import.source_row` for lineage.

## `mobilisation_lead`

Source: `1.Mobilisation Lead`; 280 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `candidate_id` | `text` | no | PK |
| `learner_id` | `text` | yes | FK → learner_profile.learner_id |
| `lead_date` | `date` | yes |  |
| `candidate_name` | `text` | yes |  |
| `mobile` | `text` | yes |  |
| `gender` | `text` | yes |  |
| `age` | `integer` | yes |  |
| `community_area` | `text` | yes |  |
| `source_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: source_type |
| `programme_interested_id` | `text` | yes | FK → reference_list.reference_value_id; list: programme |
| `education_level_id` | `text` | yes | FK → reference_list.reference_value_id; list: education_level |
| `employment_status_id` | `text` | yes | FK → reference_list.reference_value_id; list: employment_status |
| `mobilisation_activity` | `text` | yes |  |
| `current_status_id` | `text` | yes | FK → reference_list.reference_value_id; list: lead_status |
| `follow_up_date` | `date` | yes |  |
| `assigned_associate_id` | `text` | yes | FK → staff.staff_id |
| `consent_collected` | `boolean` | yes |  |
| `remarks` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `lead_follow_up`

Source: `2.Lead Follow-up`; 560 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `followup_id` | `text` | no | PK |
| `lead_id` | `text` | no | FK → mobilisation_lead.candidate_id |
| `follow_up_date` | `date` | yes |  |
| `stage_id` | `text` | yes | FK → reference_list.reference_value_id; list: lead_stage |
| `follow_up_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: follow_up_type |
| `channel_id` | `text` | yes | FK → reference_list.reference_value_id; list: channel |
| `reason` | `text` | yes |  |
| `outcome_id` | `text` | yes | FK → reference_list.reference_value_id; list: follow_up_outcome |
| `next_follow_up_date` | `date` | yes |  |
| `priority_id` | `text` | yes | FK → reference_list.reference_value_id; list: priority |
| `owner_staff_id` | `text` | yes | FK → staff.staff_id |
| `closure_status_id` | `text` | yes | FK → reference_list.reference_value_id; list: closure_status |
| `notes` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `mobilisation_activity`

Source: `3.Mobilisation Activity`; 810 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `activity_id` | `text` | no | PK |
| `activity_date` | `date` | yes |  |
| `associate_staff_id` | `text` | yes | FK → staff.staff_id |
| `activity_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: activity_type |
| `partner_organisation_id` | `text` | yes | FK → partner_organisation.partner_organisation_id |
| `location` | `text` | yes |  |
| `time_slot` | `text` | yes |  |
| `contact_person` | `text` | yes |  |
| `contact_number` | `text` | yes |  |
| `channel_id` | `text` | yes | FK → reference_list.reference_value_id; list: channel |
| `target_outreach` | `integer` | yes |  |
| `participants_reached` | `integer` | yes |  |
| `leads_generated` | `integer` | yes |  |
| `enrolments_expected` | `integer` | yes |  |
| `followups_completed` | `integer` | yes |  |
| `key_issues` | `text` | yes |  |
| `next_action` | `text` | yes |  |
| `next_follow_up_date` | `date` | yes |  |
| `status_id` | `text` | yes | FK → reference_list.reference_value_id; list: activity_status |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `partner_organisation`

Source: `4.Partner Organisation`; 12 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `partner_organisation_id` | `text` | no | PK |
| `organisation_name` | `text` | yes |  |
| `partnership_status_id` | `text` | yes | FK → reference_list.reference_value_id; list: partnership_status |
| `mou_signed_date` | `date` | yes |  |
| `contact_person` | `text` | yes |  |
| `contact_email` | `text` | yes |  |
| `contact_phone` | `text` | yes |  |
| `notes` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `monthly_target`

Source: `5.Monthly Target`; 162 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `target_id` | `text` | no | PK |
| `staff_id` | `text` | no | FK → staff.staff_id |
| `month` | `date` | no |  |
| `contact_target` | `integer` | yes |  |
| `lead_target` | `integer` | yes |  |
| `enrolment_target` | `integer` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `report_meeting_log`

Source: `6.Report & Meeting Log`; 216 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `log_id` | `text` | no | PK |
| `log_date` | `date` | yes |  |
| `type_id` | `text` | yes | FK → reference_list.reference_value_id; list: report_meeting_type |
| `audience` | `text` | yes |  |
| `key_updates` | `text` | yes |  |
| `decisions_taken` | `text` | yes |  |
| `action_items` | `text` | yes |  |
| `owner_staff_id` | `text` | yes | FK → staff.staff_id |
| `due_date` | `date` | yes |  |
| `status_id` | `text` | yes | FK → reference_list.reference_value_id; list: report_meeting_status |
| `evidence_link` | `text` | yes |  |
| `remarks` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `learner_profile`

Source: `7.Learner Profile`; 215 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `learner_id` | `text` | no | PK |
| `registration_no` | `text` | yes |  |
| `first_name` | `text` | yes |  |
| `middle_name` | `text` | yes |  |
| `last_name` | `text` | yes |  |
| `date_of_birth` | `date` | yes |  |
| `gender` | `text` | yes |  |
| `address` | `text` | yes |  |
| `state` | `text` | yes |  |
| `neighbourhood` | `text` | yes |  |
| `district_city` | `text` | yes |  |
| `pin_code` | `text` | yes |  |
| `email` | `text` | yes |  |
| `qualification_id` | `text` | yes | FK → reference_list.reference_value_id; list: qualification |
| `qualification_notes` | `text` | yes |  |
| `languages_known` | `text` | yes |  |
| `family_member_count` | `integer` | yes |  |
| `residence_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: residence_type |
| `residence_ownership_id` | `text` | yes | FK → reference_list.reference_value_id; list: residence_ownership |
| `family_income_band_id` | `text` | yes | FK → reference_list.reference_value_id; list: family_income_band |
| `monthly_rent` | `numeric` | yes |  |
| `per_capita_income` | `numeric` | yes |  |
| `apl_bpl` | `text` | yes |  |
| `is_active` | `boolean` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `family_contact`

Source: `8.Family Contact`; 286 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `contact_id` | `text` | no | PK |
| `learner_id` | `text` | no | FK → learner_profile.learner_id |
| `contact_name` | `text` | yes |  |
| `relationship_to_learner_id` | `text` | yes | FK → reference_list.reference_value_id; list: relationship_to_learner |
| `contact_role_id` | `text` | yes | FK → reference_list.reference_value_id; list: contact_role |
| `mobile` | `text` | yes |  |
| `email` | `text` | yes |  |
| `auth_user_id` | `uuid` | yes | FK → auth.users.id |
| `login_phone` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `learner_sensitive_details`

Source: `9.Learner Sensitive Details`; 215 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `learner_id` | `text` | no | PK; FK → learner_profile.learner_id |
| `aadhaar_number` | `text` | no |  |
| `pan_number` | `text` | yes |  |
| `diagnosis_disability_type` | `text` | yes |  |
| `disability_percent` | `numeric` | yes |  |
| `udid` | `text` | yes |  |
| `associated_medical_condition` | `text` | yes |  |
| `medication_details` | `text` | yes |  |
| `family_income_exact` | `numeric` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `batch`

Source: `10.Batch`; 20 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `batch_id` | `text` | no | PK |
| `financial_year` | `text` | yes |  |
| `centre_id` | `text` | yes | FK → reference_list.reference_value_id; list: centre |
| `center_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: centre_type |
| `quarter` | `text` | yes |  |
| `batch_number` | `integer` | yes |  |
| `program_id` | `text` | yes | FK → reference_list.reference_value_id; list: programme |
| `shift_id` | `text` | yes | FK → reference_list.reference_value_id; list: shift |
| `planned_start_date` | `date` | yes |  |
| `planned_end_date` | `date` | yes |  |
| `actual_start_date` | `date` | yes |  |
| `actual_end_date` | `date` | yes |  |
| `is_active` | `boolean` | yes |  |
| `max_students` | `integer` | yes |  |
| `class_days` | `text` | yes |  |
| `default_start_time` | `time` | yes |  |
| `default_end_time` | `time` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `enrolment`

Source: `11.Enrolment`; 220 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `enrolment_id` | `text` | no | PK |
| `learner_id` | `text` | no | FK → learner_profile.learner_id |
| `batch_id` | `text` | no | FK → batch.batch_id |
| `enrolment_date` | `date` | yes |  |
| `status_id` | `text` | yes | FK → reference_list.reference_value_id; list: enrolment_status |
| `dropout_reason` | `text` | yes |  |
| `exit_date` | `date` | yes |  |
| `exit_outcome_id` | `text` | yes | FK → reference_list.reference_value_id; list: exit_outcome |
| `program_duration_weeks` | `integer` | yes |  |
| `source_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: source_type |
| `source_name` | `text` | yes |  |
| `sourcing_associate_id` | `text` | yes | FK → staff.staff_id |
| `parents_meeting_relationship_id` | `text` | yes | FK → reference_list.reference_value_id; list: parents_meeting_relationship |
| `total_fee_amount` | `numeric` | yes |  |
| `supported_subsidy_amount` | `numeric` | yes |  |
| `id_proof_submitted` | `boolean` | yes |  |
| `education_proof_submitted` | `boolean` | yes |  |
| `photo_submitted` | `boolean` | yes |  |
| `consent_form_submitted` | `boolean` | yes |  |
| `document_remarks` | `text` | yes |  |
| `supporter_contact_id` | `text` | yes | FK → family_contact.contact_id |
| `supporter_apron_date` | `date` | yes |  |
| `is_active` | `boolean` | yes |  |
| `programme_associate_staff_id` | `text` | yes | FK → staff.staff_id |
| `enrolled_by_staff_id` | `text` | yes | FK → staff.staff_id |
| `docs_provided` | `boolean` | yes |  |
| `orientation_scheduled_date` | `date` | yes |  |
| `orientation_attended` | `boolean` | yes |  |
| `programme_level_id` | `text` | yes | FK → reference_list.reference_value_id; list: programme_level |
| `consent_given` | `boolean` | yes |  |
| `consent_date` | `date` | yes |  |
| `graduation_notes` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `fee_instalment`

Source: `12.Fee Instalment`; 660 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `instalment_id` | `text` | no | PK |
| `enrolment_id` | `text` | no | FK → enrolment.enrolment_id |
| `instalment_number` | `integer` | no |  |
| `amount_due` | `numeric` | no |  |
| `due_date` | `date` | yes |  |
| `remarks` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `fee_payment`

Source: `13.Fee Payment`; 597 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `payment_id` | `text` | no | PK |
| `enrolment_id` | `text` | no | FK → enrolment.enrolment_id |
| `payment_date` | `date` | yes |  |
| `amount` | `numeric` | no |  |
| `payment_type_id` | `text` | no | FK → reference_list.reference_value_id; list: payment_type |
| `payment_mode_id` | `text` | yes | FK → reference_list.reference_value_id; list: payment_mode |
| `receipt_number` | `text` | yes |  |
| `received_by_staff_id` | `text` | yes | FK → staff.staff_id |
| `remarks` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `master_programme_schedule`

Source: `14.Master Programme Schedule`; 120 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `master_programme_schedule_id` | `text` | no | PK |
| `programme_id` | `text` | no | FK → reference_list.reference_value_id; list: programme |
| `template_name` | `text` | no |  |
| `week_number` | `integer` | no |  |
| `session_number` | `integer` | no |  |
| `session_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: session_type |
| `topic_id` | `text` | yes | FK → standard_topic.topic_id |
| `extra_topic_note` | `text` | yes |  |
| `assessment_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: assessment_type |
| `assessment_no` | `text` | yes |  |
| `home_programme` | `text` | yes |  |
| `notes` | `text` | yes |  |
| `is_active` | `boolean` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `standard_topic`

Source: `15.Standard Topic`; 50 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `topic_id` | `text` | no | PK |
| `session_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: session_type |
| `topic_name` | `text` | yes |  |
| `curriculum_strand_id` | `text` | yes | FK → reference_list.reference_value_id; list: curriculum_strand |
| `sort_order` | `integer` | yes |  |
| `module_name` | `text` | yes |  |
| `topic_description` | `text` | yes |  |
| `is_active` | `boolean` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `batch_schedule`

Source: `16.Batch Schedule`; 1320 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `batch_schedule_id` | `text` | no | PK |
| `batch_id` | `text` | no | FK → batch.batch_id |
| `master_programme_schedule_id` | `text` | yes | FK → master_programme_schedule.master_programme_schedule_id |
| `week_number` | `integer` | no |  |
| `session_number` | `integer` | no |  |
| `planned_session_date` | `date` | yes |  |
| `actual_session_date` | `date` | yes |  |
| `session_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: session_type |
| `topic_id` | `text` | yes | FK → standard_topic.topic_id |
| `facilitator_staff_id` | `text` | yes | FK → staff.staff_id |
| `extra_topic_note` | `text` | yes |  |
| `other_faculty_note` | `text` | yes |  |
| `assessment_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: assessment_type |
| `assessment_no` | `text` | yes |  |
| `home_programme` | `text` | yes |  |
| `holiday_note` | `text` | yes |  |
| `start_time` | `time` | yes |  |
| `end_time` | `time` | yes |  |
| `delivery_status_id` | `text` | yes | FK → reference_list.reference_value_id; list: delivery_status |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `learner_session_log`

Source: `17.Learner Session Log`; 1620 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `learner_session_log_id` | `text` | no | PK |
| `enrolment_id` | `text` | no | FK → enrolment.enrolment_id |
| `batch_schedule_id` | `text` | no | FK → batch_schedule.batch_schedule_id |
| `attendance_mark` | `text` | yes |  |
| `home_practice_status_id` | `text` | yes | FK → reference_list.reference_value_id; list: home_practice_status |
| `journal_status_id` | `text` | yes | FK → reference_list.reference_value_id; list: journal_status |
| `notes` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |
| `attendance_reference_id` | generated `text` | yes | FK → reference_list; preserves original P/A/PL/H/L in attendance_mark |

## `goal`

Source: `18.Goal`; 0 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `goal_id` | `text` | no | PK |
| `enrolment_id` | `text` | no | FK → enrolment.enrolment_id |
| `goal_number` | `integer` | no |  |
| `goal_section_id` | `text` | yes | FK → reference_list.reference_value_id; list: goal_section |
| `responsible_contact_id` | `text` | yes | FK → family_contact.contact_id |
| `plan_date` | `date` | yes |  |
| `focus_area` | `text` | yes |  |
| `skill_module` | `text` | yes |  |
| `goal_statement` | `text` | yes |  |
| `long_term_goal` | `text` | yes |  |
| `tools_and_strategies` | `text` | yes |  |
| `family_involvement_action` | `text` | yes |  |
| `involvement_area` | `text` | yes |  |
| `plan_of_action` | `text` | yes |  |
| `goal_status_id` | `text` | yes | FK → reference_list.reference_value_id; list: goal_status |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `goal_review`

Source: `19.Goal Review`; 0 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `goal_review_id` | `text` | no | PK |
| `goal_id` | `text` | no | FK → goal.goal_id |
| `milestone_week` | `integer` | no |  |
| `review_date` | `date` | yes |  |
| `faculty_rating_id` | `text` | yes | FK → reference_list.reference_value_id; list: faculty_rating |
| `family_rating_id` | `text` | yes | FK → reference_list.reference_value_id; list: family_rating |
| `skill_transfer` | `text` | yes | FK → reference_list.reference_value_id; list: skill_transfer |
| `status_id` | `text` | yes | FK → reference_list.reference_value_id; list: goal_review_status |
| `what_is_working` | `text` | yes |  |
| `what_needs_change` | `text` | yes |  |
| `family_inputs` | `text` | yes |  |
| `faculty_remarks` | `text` | yes |  |
| `remarks_or_evidence` | `text` | yes |  |
| `readiness_indicators` | `text` | yes |  |
| `next_steps` | `text` | yes |  |
| `ideal_seed_pathway` | `text` | yes | FK → reference_list.reference_value_id; list: seed_pathway |
| `ffm_ffi_date` | `date` | yes |  |
| `faculty_rating_score` | `numeric` | yes | SMART 1–5; Functional/Hospitality 0–5; other sections unchanged |
| `family_rating_score` | `numeric` | yes | SMART 1–5; Functional/Hospitality 0–5; other sections unchanged |
| `ideal_seed_pathway_other` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `assessment_event`

Source: `20.Assessment Event`; 0 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `assessment_event_id` | `text` | no | PK |
| `enrolment_id` | `text` | no | FK → enrolment.enrolment_id |
| `batch_schedule_id` | `text` | yes | FK → batch_schedule.batch_schedule_id |
| `assessment_type_id` | `text` | no | FK → reference_list.reference_value_id; list: assessment_type |
| `rubric_version` | `text` | no |  |
| `assessment_no` | `text` | yes |  |
| `assessment_date` | `date` | yes |  |
| `topic_or_dish` | `text` | yes |  |
| `assessor_staff_id` | `text` | yes | FK → staff.staff_id |
| `supported_by_contact_id` | `text` | yes | FK → family_contact.contact_id |
| `result_status_id` | `text` | yes | FK → reference_list.reference_value_id; list: assessment_result_status |
| `module_name` | `text` | yes |  |
| `remarks` | `text` | yes |  |
| `iq_value` | `text` | yes |  |
| `height_value` | `numeric` | yes |  |
| `weight_value` | `numeric` | yes |  |
| `assessment_stage_id` | `text` | yes | FK → reference_list.reference_value_id; list: assessment_stage |
| `measure_method_id` | `text` | yes | FK → reference_list.reference_value_id; list: measure_method |
| `signed_at` | `timestamptz` | yes |  |
| `approved_by_staff_id` | `text` | yes | FK → staff.staff_id |
| `approved_at` | `timestamptz` | yes |  |
| `parents_goals` | `text` | yes |  |
| `achievable_goals` | `text` | yes |  |
| `implementation_plan` | `text` | yes |  |
| `recommendations` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `criterion_catalogue`

Source: `21.Criterion Catalogue`; 210 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `criterion_id` | `text` | no | PK |
| `assessment_type_id` | `text` | no | FK → reference_list.reference_value_id; list: assessment_type |
| `rubric_version` | `text` | no |  |
| `criterion_number` | `integer` | no |  |
| `criterion_name` | `text` | no |  |
| `criterion_description` | `text` | yes |  |
| `reference_scale` | `text` | yes |  |
| `maximum_score` | `numeric` | yes |  |
| `display_order` | `integer` | yes |  |
| `section` | `text` | yes |  |
| `weight` | `numeric` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `criterion_score`

Source: `22.Criterion Score`; 0 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `criterion_score_id` | `text` | no | PK |
| `assessment_event_id` | `text` | no | FK → assessment_event.assessment_event_id |
| `criterion_id` | `text` | no | FK → criterion_catalogue.criterion_id |
| `score_value` | `numeric` | yes |  |
| `rating_id` | `text` | yes | FK → reference_list.reference_value_id; list: criterion_rating |
| `remark_text` | `text` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `staff`

Source: `23.Staff`; 20 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `staff_id` | `text` | no | PK |
| `auth_user_id` | `uuid` | yes | FK → auth.users.id |
| `full_name` | `text` | yes |  |
| `email` | `text` | yes |  |
| `job_title` | `text` | yes |  |
| `staff_type_id` | `text` | yes | FK → reference_list.reference_value_id; list: staff_type |
| `is_active` | `boolean` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## `reference_list`

Source: `24.Reference List`; 154 rows at inspection.

| Field | SQL type | Nullable | Key / option group |
|---|---|---|---|
| `reference_value_id` | `text` | no | PK |
| `list_name` | `text` | no |  |
| `display_label` | `text` | no |  |
| `sort_order` | `integer` | yes |  |
| `is_active` | `boolean` | yes |  |
| `created_at` | `timestamptz` | yes |  |
| `updated_at` | `timestamptz` | yes |  |
| `created_by` | `text` | yes | FK → staff.staff_id |
| `updated_by` | `text` | yes | FK → staff.staff_id |

## Review-fix integrity metadata

These columns mirror parent context. Do not map source values into them; triggers/generated expressions fill them.

| Table | Added integrity columns | Purpose |
|---|---|---|
| `learner_session_log` | `attendance_reference_id text` (generated), `context_learner_id text`, `context_batch_id text` | Raw attendance FK and enrolment/session batch integrity |
| `goal` | `context_learner_id text`, `context_batch_id text`, `context_programme_id text` (generated), `context_section_key text` (generated) | Learner/contact, batch/programme and review section integrity |
| `goal_review` | `context_section_key text` | FK mirrors the goal section; CHECK applies its approved numeric range |
| `assessment_event` | `context_learner_id text`, `context_batch_id text` | Learner/contact and enrolment/session batch integrity |
| `criterion_catalogue` | `context_score_ceiling numeric` (generated) | Generated ceiling: source maximum, or Infinity only as an internal unbounded sentinel |
| `criterion_score` | `context_assessment_type_id text`, `context_rubric_version text`, `context_score_ceiling numeric` | FKs match the event and criterion type/version/ceiling; score CHECK uses the same ceiling |
| `ids_import.source_row` | `chunk_first_row integer`, `chunk_last_row integer` | Filled from chunk; null iff unchunked; composite FK and range CHECK bind the scope |

All new domain context columns are NOT NULL; attendance_reference_id alone remains nullable when the raw attendance mark is null. Source-row chunk bounds are nullable only for unchunked staging. Original source fields, values and nullability are unchanged.


2026-11-14: Monthly Target.month remains date/first-of-month. For v2, exact
YYYY-MM source text deterministically maps to YYYY-MM-01, preserving raw text
in lineage. Active Reference List has 165 options; earlier counts above are
historical. New source row counts/gids are in source-audit-v2.json.
