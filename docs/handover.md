# Veruschka IDS handover — additive history

## 2026-11-13 — Stage 1 environment/access check

The repository had only a README; no AGENTS.md, model, migration or loader
documentation existed. Latest main and checked-out commit were both
`47343a2a71b984805218cfe179c74f68cbf0b625`. GitHub, Drive/Sheets and Supabase
connectors were available. The worker had both required variable names and its
project ref matched the allowlist. A read-only query via api.supabase.com returned
connectivity_ok=1 on the allowed project. Secret values were not printed.

The target was Veruschka-IDS-SampleProject, ACTIVE_HEALTHY, PostgreSQL 17.
Direct remote Postgres/TCP was not tested; no TCP allowance was configured.
The Drive connector could retrieve Veruschka_ILS_Data_Model_v3.drawio.
No hosted, source or repository changes were made at this stage.

## 2026-11-13 — Stage 2 source inspection history

User authorized read-only inspection. Actual inventory: 25 tabs (Model Guide,
23 data tabs and 24.Reference List), 7,747 data/reference rows. Repeat reads
matched all values across those rows. No missing/duplicate primary keys,
populated orphan FKs or tested composite-key duplicates were found. All populated
data rectangles contained literal values, not cell formulas. Source grid sizes
are not record counts. Four tabs are headers-only: Goal, Goal Review, Assessment
Event, Criterion Score. Counts, actual header fields and source fingerprints are
preserved in source-audit.json; no raw rows were committed.

The diagram and Model Guide agree on tables and basic grains. The Guide is a
summary rather than a field dictionary. The detailed diagram supplied field,
relationship, type and constraint detail later approved by the user.
Identified differences: Activity lacks next_follow_up_date; docs_provided is
boolean in the source rather than diagram text; Assessment session optionality
is not explicit in the header; overview template_id differs from the detailed
master_programme_schedule_id; some session wording says Independent although
there is no such option; the diagram's broad-access note conflicts with the
user's closed-access requirement. These are resolved below, not silently chosen.

Sheets rate-limited two formula/format reads. A later batched read succeeded;
no data completeness claim depends on a failed read.

## 2026-11-13 — User decisions and fresh conditional checks

The user approved the detailed diagram, with their listed exceptions, and Stage 3
through opening a PR only. No migration application, source load or merge was
approved. The read-only conditional checks were repeated against the live source:

| Check | Result | Implemented decision |
|---|---|---|
| Mobilisation Lead | 280 leads; 215 Converted, 65 other statuses | Retain converted leads |
| Learner links | 215 non-null links, 215 distinct learners, zero repeated learner IDs | Unique learner_id on leads; nulls remain nonunique |
| Example converted row references | 1.Mobilisation Lead rows 3, 4, 5; no names | Evidence only |
| Aadhaar | All 215 rows nonblank; blank row list empty | Required/nonblank; keep raw text, never invent format validation for dummy values |

| Approved model decision | Result |
|---|---|
| Diagram-only enrolment, curriculum/session, fee, goal/review, assessment/catalogue and other rules | Included, with explicit exception handling described in model.md |
| Activity next_follow_up_date | Nullable and unpopulated on source import |
| docs_provided | Boolean |
| Assessment Event session | Nullable |
| Template FK | master_programme_schedule_id |
| Reference List | Authoritative; nine session types; stale FUNCTIONAL_AND_CULINARY ignored |
| Access | Unexposed schemas, all tables RLS, no policies/grants; disregard diagram's everyone-can-see note |
| Partial attendance | Intentional; missing logs never imply absence |
| 61 weekly-check mismatches | Retain with warnings; never quarantine solely for these |
| Holiday/Rescheduled/Cancelled dates/logs | Retain as source facts, no consistency constraints on these combinations |
| Partner MOU mismatch | Retain with warnings |
| Lead next-date summary | Preserve source value; derive later |
| Fees | Preserve gross, subsidy, scheduled net amounts; interpretation remains open |
| Wholly blank columns | Null, no inference |
| Timestamps | Interpret source wall times as Asia/Kolkata; workbook timezone remains an open question |
| Remaining field meanings/sets | Preserve source text/numbers; open questions are not blockers |

### Retained source exceptions

source-audit.json contains exact affected source row references for the following
approved warnings, without personal values:

- 61 weekly-check rows differ under the first-held batch-session/date interpretation.
- 31 Holiday and 30 Rescheduled sessions have actual dates; 44 logs reference
  Holiday/Cancelled sessions. These remain legitimate source facts.
- Partner MOU_SIGNED rows 5, 9, 13 have no date; IN_DISCUSSION rows 4, 8, 12 have dates.
- 187 leads have an open follow-up with a next date and a blank lead summary date.
- Attendance logs cover only 32/220 enrolments and 148/1,320 scheduled sessions.
- All 220 enrolments have 24-week duration. Cohorts have two or three sessions
  per week in the source.
- 590 payments and 7 refunds are all positive. Source instalment sums match gross
  minus subsidy for all 220 enrolments; this observation does not settle meaning.
- Old dropdown validations contain outdated IDs and stale date/time formats occur
  on some boolean/text/assessment-number columns. Parse by field specification and
  raw type, never by formatting alone. Source dropdowns were not repaired.
- Source records predate some referenced staff and template audit times. Imported
  audit timestamps are retained, not treated as evidence of record creation order.

### Open questions — intentionally not blockers

1. Workbook timezone is America/Los_Angeles; user instructed Asia/Kolkata. Confirm
   the operational convention later. Preserve serial/display values and the chosen
   parse timezone in each import run; do not silently use the workbook default.
2. Meaning of ffm_ffi_date, IQ representation, height/weight units and whether
   assessment_date is also the measurement date.
3. Registration-number uniqueness; gender, APL/BPL and quarter permitted sets.
4. Text-rating/numeric-rating mappings and rubric weight/score interpretation.
   Source catalogue versions BASE-V1, FUNC-V1, CUL-V1, ICUL-V1, WEEK-V1, FINAL-V1
   currently use maximum 5 and weight 1. No derived weighted grading is implemented.
5. Gross fee/subsidy/net-due interpretation. There is no independent source net_due
   field; scheduled_net_due is a view over preserved instalment amounts.
6. Meaning of per_capita_income, which is wholly blank; do not calculate it from
   incomplete income/member data. Keep language/class-day source text intact.

No repeated learner links were found, so the conditional multiple-leads question
is resolved for this baseline. If a later approved extract has repeated links,
stop before loading; do not drop the unique constraint or merge people silently.

## 2026-11-13 — Stage 3 implementation and validation history

Feature branch: feat/private-ids-schema-stage3, based on latest main
47343a2a71b984805218cfe179c74f68cbf0b625. New timestamped migration was created
with Supabase CLI 3.1.0 using migration new; no prior applied migration exists in
the repository. CLI help was checked after the v3 target/consent change. The
changelog's Postgres 17.11 extension warnings do not affect this migration: it
uses no ltree, btree_gist, pgcrypto encryption or custom operators.

Added 24 domain tables, four import/audit tables, private fee views, explicit FKs,
indexes, constraints and security-invoker integrity functions. No deployment job,
remote write command or source loader is included. The seed emits invented dummy
SQL and makes no connection. Stage 4 credential/network verification, estimation,
representative trial and idempotent loader implementation remain future work.

Local validation uses a digest-pinned PostgreSQL 17.11 image and minimal auth.users
and Supabase role fixtures. Tests run in a network-isolated disposable container.
See validation.md for final results and limits. All validation data is dummy data;
no source extract was loaded into the local test database.

### Hosted baseline, read-only

The Stage 3 catalog check found zero public tables and no ids/ids_import schemas.
Performance advisor returned no findings. Security advisor reported two existing
warnings for public.rls_auto_enable(): it is SECURITY DEFINER and executable by
anon and authenticated. This function was not created, invoked or changed by this
PR. Existing event triggers/Supabase platform behavior were not emulated locally.

Remediation references:
- [Anonymous execution warning](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable)
- [Authenticated execution warning](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)

Investigate/revoke unnecessary execution separately under appropriate approval;
do not conflate those existing warnings with security of the unapplied migration.

### Review gate and later stages

Review the PR and explicitly approve application before any hosted DDL. At that
time reconfirm allowed project/name, current main/migration history, exposed API
schemas, credentials/network and advisors. Refuse application if ids or ids_import
is exposed. Apply only the reviewed migration, then verify catalog fingerprints,
constraints, indexes, RLS, zero policies/grants and advisors. Do not enable access.

No source tab/range is authorized for loading by Stage 3 approval. Stage 4 must
first estimate rows/output records/chunks/tool calls/time and run a representative
trial. Keep raw extracts outside Git, checkpoint committed chunks, reconcile every
considered row and retain approved warnings. Create the required Google failure
Sheet in the project folder only during an approved stage: one source per tab,
exact columns source file / row reference / reason for failure. It does not exist
as a deliverable of this PR. Never retry a failed or uncertain write blindly.

Migration and load outcome at this handover: **hosted migration not applied;
zero source records loaded; no policies/access model approved; PR must not merge
automatically.**
