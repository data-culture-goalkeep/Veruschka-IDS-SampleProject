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

## 2026-11-13 — Follow-up: both reviews and fixes on PR #1

This section supplements the original Stage 3 history above. The user authorized
fixing every review finding on the same feature branch, local validation and a
push to PR #1. They explicitly prohibited hosted application and merging.

Review sources:
- GitHub P1 comment `4562558469`, attached to original migration lines 56–57:
  source rows could claim a checkpoint from a different sheet/range.
- Read-only chat review of commit `59dff307`: incomplete run/file lineage,
  unknown credit becoming zero, overbroad rubric freeze, snapshot-dependent
  relationship checks, missing source-equivalent bootstrap test, duplicate
  indexes and incomplete ER edges. It also recommended hardening the existing
  public event-trigger function's execution permissions.

The original migration is unchanged. Additive migration
`20261113125216_review_integrity_and_privacy_fixes.sql` contains the fixes:

| Finding | Fix / retained limitation |
|---|---|
| GitHub P1 chunk scope | Source-row FK now includes chunk/run/sheet/first/last bounds; copied bounds plus CHECK enforce original-row membership, including parent scope changes |
| Chat run/file lineage | Composite FK requires source_row.source_file_id to equal its run's file |
| Existing public function permissions | Revoke EXECUTE from PUBLIC, anon, authenticated only; retain owner, function body and registered event trigger |
| Fee credit | No instalments means NULL due, balance and credit, even if payments exist |
| Rubric provenance | Only identifier/definition/scoring columns are protected; source_row_id and source audit timestamps/actors can change without rewriting the definition |
| Relationship concurrency | Composite FKs enforce learner/contact, enrolment/session batch, ILS goal and event/criterion rubric context; remove the global parent-scan trigger |
| Conditional/rubric consistency | Non-null context keys and CHECKs enforce goal-section ranges and criterion ceilings without nullable-composite-FK bypasses |
| Used-rubric existence race | Score writes hold SHARE on the criterion; actual definition updates require READ COMMITTED and reject other isolation levels with 0A000 |
| Staff/Reference audit cycle | Documented one deferred bootstrap transaction; committed test preserves nonnull created_by/updated_by on both sides |
| Index redundancy | Remove compatible nonunique indexes already covered by a unique-key prefix; FK coverage remains verified |
| ER/docs mismatch | Complete attendance-reference and source-row/chunk edges; add all composite keys and document derived context separately from source fields |

### Derived context is metadata, not source repair

The `context_*` columns and chunk bounds mirror known parent keys/rules. The
loader must omit these columns: triggers/generated expressions populate them,
and declarative FKs validate the context even if a transaction saw an old parent
snapshot. Raw source fields are untouched. A missing catalogue maximum remains
NULL in maximum_score; an internal Infinity ceiling means no supplied upper
bound. A missing goal section remains NULL; an internal empty context key allows
the FK to validate that missing section without skipping the relationship.

Parent context changes do not silently cascade. To make a compatible deliberate
change, defer the context FKs, update the parent, refresh the affected child rows,
then make constraints immediate before commit. Wrong-learner, wrong-batch,
wrong-rubric and invalid numeric-range changes still fail. The old table-scan
trigger is gone. The old trigger-based check error codes become FK error codes
where appropriate; the original regression tests were updated accordingly.

Supported isolation: ordinary context integrity is declarative, with concurrent
parent-change tests at READ COMMITTED and REPEATABLE READ. Only actual updates
to catalogue definition/scoring fields are restricted to READ COMMITTED because
used-definition immutability still needs a fresh existence-check snapshot.
Metadata-only catalogue updates do not have this restriction. Concurrent tests
verify that a waiting definition change sees the newly committed score and fails.
No claim is made that every possible application transaction has been tested.

### Source-equivalent bootstrap procedure

Staff rows reference staff_type options; reference rows name staff audit actors.
When an approved loader is eventually built, it must bootstrap these two sources
in a single transaction with `SET CONSTRAINTS ALL DEFERRED`, insert their real
IDs and actor links, then `SET CONSTRAINTS ALL IMMEDIATE` before committing. Do
not strip the actors, invent users or commit one side of the cycle independently.
`tests/bootstrap.sql` commits and reads back the analogous dummy cycle. This
does not authorize a real source load or define the remaining chunking plan.

### Function assessment and unchanged hosted state

The read-only review found public.rls_auto_enable() returns event_trigger, is
owned by postgres, uses SECURITY DEFINER with fixed pg_catalog search_path,
quotes table identifiers, and only enables RLS on newly created public tables.
It catches failures and logs them; it is not a substitute for explicit RLS in
the migrations. PostgreSQL rejects ordinary function invocation, so the broad
EXECUTE ACL did not establish a callable API data-exposure path. The narrow
revoke is hardening and is tested locally with a compatibility event trigger.

The actual Supabase function and its ACL have **not** been changed. The proposed
revoke takes effect only after explicit approval to apply the reviewed migrations.
No live warning is claimed resolved, no new policies/grants were added, no source
file was edited or loaded, and PR #1 remains unmerged.

Local verification: original contract, review regressions, committed bootstrap,
model/catalog/ER agreement, three real concurrent races and two isolation
rejection cases all passed on PostgreSQL 17.11. See validation.md for coverage
and limitations. The four empty source tabs and all original business-definition
open questions above remain unchanged; they were not review findings to infer away.


## 2026-11-13 — Approved hosted application via worker

The user explicitly authorized both migrations from PR #1 head
`decd704109cc30fdd443a38d2af8880b23e8f03a` on the allowed project
`uzofrrrtwqjmtytrbqfr` only. Applied in timestamp order through the worker's
standard Management API migration endpoint. No seed or source data was loaded;
no access policies were added and no merge was performed. This application
supersedes the earlier unapplied-state observations, which remain dated history.

The endpoint assigned versions different from the original file timestamps.
Renamed with `git mv`, with SQL bytes verified identical to the approved head:

| Original filename | Recorded-version filename |
|---|---|
| `20261113095327_private_ids_schema.sql` | `20261113125204_private_ids_schema.sql` |
| `20261113111942_review_integrity_and_privacy_fixes.sql` | `20261113125216_review_integrity_and_privacy_fixes.sql` |

Hosted verification: both recorded versions exist; ids has 24 tables and
ids_import has four; all 28 have RLS and zero policies. No table/view/sequence/
function ACL grants to PUBLIC, anon, authenticated or service_role exist in
these schemas. Both fee views have security_invoker=true. EXECUTE on
public.rls_auto_enable() is revoked from PUBLIC, anon and authenticated.
Data API exposed schemas remain public,graphql_public. Security advisor:
28 INFO rls_enabled_no_policy findings, expected for the approved closed
access model; zero WARN or ERROR findings. The two prior function warnings
are absent. No automatic remediation or access-model changes were made.


## 2026-11-13 — Trial/full load paused at first-run progress-state gate

The user authorized the synthetic-data trial and full load only on
Veruschka-IDS-SampleProject (`uzofrrrtwqjmtytrbqfr`), through the worker route
using PR #2 commit `097b1f00bf68a97faebd02ffcb9666d34fbf8229`. They required an
immediate stop on failed, uncertain or unexpected results and explicit approval
after read-only reconciliation of missing/untrusted progress state.

The first journal inspection reported **RECONCILIATION_REQUIRED**: there was no
trusted first-run state. No Loader.load call or database write was performed.
The required read-only reconciliation then completed at **21:12:18 IST**
(15:42:18 UTC), returning **mode=first**, not recovery of an existing import.
The database trial and full load remain paused pending the user's explicit
approval to resume. This is not a successful load or a completed 7,747-row
reconciliation. Do not interpret the newly provisioned local journal as approval.

### Read-only findings

- Worker preflight confirmed the exact allowed healthy project, expected migration
  versions, all 28 tables with RLS, zero policies and no private-model object ACL
  grants to PUBLIC, anon, authenticated or service_role. Exposed API schemas remain
  public,graphql_public, excluding ids and ids_import.
- Initial read-only inventory: every one of the 24 domain and four audit/import
  tables had zero rows; import runs, lineage and checkpoints were all absent.
- The trial source scope was read twice: Reference List 154, Staff 20, Partner
  Organisation 12 and Learner Profile 215, totaling **401 distinct source rows**,
  or 802 observations. Both snapshots matched exactly. Every tab's source
  fingerprint matched its Stage 2 baseline, and all 401 rows transformed.
- Loader.reconcile was invoked only with READ ONLY transactions and returned
  `reconciled=true, mode=first`. It provisioned local first-run state outside the
  repository. It did not insert an import-run row or any source/business data.
- Frozen trial run: `4a5269a8-e230-4a8e-841c-8c50cf2ba31a`. Snapshot SHA-256:
  `f07434fc0a7f7e63863bf5407a802e4ac969798a9ad6379e20bdac3fe5883be5`. No raw cells or transformed records are committed.
- Local state is under /workspace/shared/ids-loader-state, outside the checkout.
  Availability across environment replacement has not been established. If it
  disappears or is untrusted, repeat the approval-gated reconciliation procedure.

### Trial write accounting

| Trial tab | Source rows read per pass | Load-considered | Loaded | Quarantined |
|---|---:|---:|---:|---:|
| 24.Reference List | 154 | 0 | 0 | 0 |
| 23.Staff | 20 | 0 | 0 | 0 |
| 4.Partner Organisation | 12 | 0 | 0 | 0 |
| 7.Learner Profile | 215 | 0 | 0 | 0 |
| Total | 401 | 0 | 0 | 0 |

No bootstrap transaction, trial insertion, chunk replay, or post-load accounting
check was attempted. Read/transformed source rows are not load-considered rows.

### Full-load accounting — not started

Expected counts below are the approved Stage 2 inventory, not fresh reads of the
remaining tabs. Actual considered/loaded/quarantined counts for this attempt
are all zero. Model Guide is documentation and is excluded from the 7,747.

| Tab | Expected source rows | Load-considered | Loaded | Quarantined | Status |
|---|---:|---:|---:|---:|---|
| 24.Reference List | 154 | 0 | 0 | 0 | Not started |
| 23.Staff | 20 | 0 | 0 | 0 | Not started |
| 4.Partner Organisation | 12 | 0 | 0 | 0 | Not started |
| 7.Learner Profile | 215 | 0 | 0 | 0 | Not started |
| 8.Family Contact | 286 | 0 | 0 | 0 | Not started |
| 9.Learner Sensitive Details | 215 | 0 | 0 | 0 | Not started |
| 10.Batch | 20 | 0 | 0 | 0 | Not started |
| 11.Enrolment | 220 | 0 | 0 | 0 | Not started |
| 1.Mobilisation Lead | 280 | 0 | 0 | 0 | Not started |
| 2.Lead Follow-up | 560 | 0 | 0 | 0 | Not started |
| 3.Mobilisation Activity | 810 | 0 | 0 | 0 | Not started |
| 5.Monthly Target | 162 | 0 | 0 | 0 | Not started |
| 6.Report & Meeting Log | 216 | 0 | 0 | 0 | Not started |
| 15.Standard Topic | 50 | 0 | 0 | 0 | Not started |
| 14.Master Programme Schedule | 120 | 0 | 0 | 0 | Not started |
| 16.Batch Schedule | 1320 | 0 | 0 | 0 | Not started |
| 12.Fee Instalment | 660 | 0 | 0 | 0 | Not started |
| 13.Fee Payment | 597 | 0 | 0 | 0 | Not started |
| 21.Criterion Catalogue | 210 | 0 | 0 | 0 | Not started |
| 17.Learner Session Log | 1620 | 0 | 0 | 0 | Not started |
| 18.Goal | 0 | 0 | 0 | 0 | Not started |
| 19.Goal Review | 0 | 0 | 0 | 0 | Not started |
| 20.Assessment Event | 0 | 0 | 0 | 0 | Not started |
| 22.Criterion Score | 0 | 0 | 0 | 0 | Not started |
| Total | 7747 | 0 | 0 | 0 | Not started |

### Verification not performed after the stop

Full-load reconciliation, repeated-chunk skip verification, final per-table
counts, final RLS/policy/grant recheck, security advisor and failure-log/quarantine
count comparison were not run. The earlier read-only preflight results above
are not a post-load verification. No sanitized failure entry was written because
no load or quarantine occurred; existing failure-log tab contents were not
rechecked in this attempt. Zero hosted data writes, failure-log writes, seed runs
and merges occurred. The docs-only PR records this stop; it does not resume loading.


### Stage timings and call accounting for this stopped attempt

Counts distinguish orchestration calls (`functions.exec`), underlying tool
invocations and Python-issued HTTP requests; they must not be added as if all
were independent tool calls. Shell polls are counted separately. Durations below
identify their clock source; blank/unmeasured timing was not reconstructed.

| Stage | Elapsed seconds / clock | Orchestration | Shell | Shell poll | Environment status | Sheets reads | Local patch | GitHub writes | Supabase HTTP reads |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Initial checkout/environment inspection | Unmeasured | 1 | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Worker preflight + initial inventory | 4.789 / shell wall | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 4 |
| Journal gate + source metadata | Unmeasured | 1 | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Two source snapshot reads | 12.9 / orchestration wall | 1 | 0 | 0 | 0 | 16 | 1 | 0 | 0 |
| Transform + read-only reconciliation | 18.373 / process monotonic | 2 | 1 | 1 | 0 | 0 | 0 | 0 | 9 |
| Database trial writes | Not started | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Full load | Not started | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Final post-load verification | Not started | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Documentation/report/PR | Unmeasured | 4 | 3 | 0 | 0 | 0 | 0 | 1 | 0 |
| Total | Not derivable: some timings unmeasured | 10 | 7 | 1 | 1 | 17 | 1 | 1 | 13 |

The 13 Supabase HTTP requests were read-only: two project GETs, two API-config
GETs, two catalog-query POSTs, one inventory-query POST, and six READ ONLY
reconciliation-query POSTs. There were no data-write requests. Documentation
counts include the documentation PR creation. No credits were measured or
inferred from these calls.
