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

## 2026-11-13 — Stage 4 read-only trial and SQL adapter PR

User approved the exact 124-row read-only trial, deferred Reference List/Staff
bootstrap design, 100-row maximum chunks and stop-on-change/conflict policy.
All 124 rows transformed after adding strict text-time parsing for four schedule
rows. Two source reads matched. There were 115 approved warning instances, zero
final quarantine candidates, 12 stale temporal formats ignored and 168 preserved
null fields. No sensitive values were printed or put in the failure log. All 25
source-log tabs were verified empty; no failure-log write or database request ran.

A new feature branch from main 51d0c92139ce385c0f93085d4e5a8b03185d8446 adds
the SQL adapter, offline tests and [load-path.md](load-path.md). The source trial
is not a hosted load or a dependency-complete FK trial. Historical exception
annotations require baseline verification before any separately approved load.
No migrations, grants, source files or seed were changed. No merge is authorized.

## 2026-11-13 — PR #2 review fixes and synthetic-data logging limitation

The planned load uses **synthetic data**. The transport is unchanged at the
user's direction: source values appear in SQL statement text and could reach
database error/query logs or HTTP request logs. Sanitizing Python exceptions and
the failure log does not remove those infrastructure exposures. **Before any real
client data is loaded, the loader must use a parameterised route and its database,
parameter, error and request-log controls must be verified first.** This PR does
not claim that logging controls were inspected or that the risk was eliminated.
No hosted database request, load or merge is authorized by these fixes.

Run-state handling now requires a separately provisioned persistent filesystem
outside the repository. All workers for the same run must use the same canonical
run-UUID state path on a filesystem supporting flock and durable fsync. State has
a separately fsync'd started marker and generation; missing, corrupt or mismatched
state never silently initializes. First execution is explicitly provisioned by
read-only reconciliation and recorded as `first`; existing runs reconcile as
`resume`. Lost state or uncertain attempts require operator-authorized read-only
reconciliation of exact run/snapshot/checkpoint/lineage/business/warning content
before a new Loader instance may write. The operator must establish that earlier
requests have settled; the loader never automatically retries an uncertain write.

An exclusive OS run lock is taken before journal inspection and retained through
preflight, all chunk/finalization requests and failure handling. Attempt UUIDs
own journal transitions, preventing another attempt from clearing in-flight state.
Input snapshots are private recursively immutable copies before validation/hash/
compilation, preventing mutation during preflight from changing approved output.

Integration tests use a digest-pinned PostgreSQL 17.11 Docker container with no
network, no published ports and no hosted credentials. Only invented fixtures
are written; source rows, private snapshots and the seed script are not used.
Coverage includes mid-chunk and deferred-bootstrap rollback, identical/changed
replay, tampered lineage, concurrent attempts, and a real COMMIT followed by a
simulated lost response. The pinned SQL parser is now mandatory, not skipped.
See validation.md for final results and remaining limits.

Final fix validation: 53 tests passed, zero skips (45 unit/parser/control,
eight PostgreSQL integration). Whitespace checks passed and the disposable
container was removed. Hosted API behavior/log controls remain unverified.

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


## 2026-11-14 — Approved database trial and full synthetic-data load completed

Recorded 2026-11-14 13:38:22 IST. The user explicitly approved resuming the reconciled first-run
state and continuing directly from a successful database trial into the full load.
Only Veruschka-IDS-SampleProject (`uzofrrrtwqjmtytrbqfr`) was accessed, on the
worker route, using the unchanged loader at PR #2 commit
`097b1f00bf68a97faebd02ffcb9666d34fbf8229`. No merge, seed, Auth-account creation,
source-sheet edit, schema/access change or transport change was performed.

The saved journal, marker and run UUID survived the date boundary. Fresh source
reads matched the frozen trial snapshot and the loader's explicit read-only
reconciliation again returned `mode=first` before the first data write. There
was no lost-state recovery, failed/uncertain data write, blind retry or route
change in this execution. The remainder used a separately identified run,
provisioned by explicit read-only reconciliation before loading.

### Database trial

Reference List and Staff were inserted together in one deferred transaction;
constraints were made immediate before commit, preserving source audit actors.
Partner Organisation and Learner Profile followed.

| Trial source | Considered | Loaded | Quarantined | Committed checkpoints |
|---|---:|---:|---:|---:|
| Reference List | 154 | 154 | 0 | 2 |
| Staff | 20 | 20 | 0 | 1 |
| Partner Organisation | 12 | 12 | 0 | 1 |
| Learner Profile | 215 | 215 | 0 | 3 |
| Total | 401 | 401 | 0 | 7 |

Each trial tab's business count, source-row lineage join and checkpoints matched.
The exact Partner Organisation chunk was repeated through the pinned adapter.
Its committed-checkpoint branch verified the existing payload/records/lineage;
before/after table, lineage and checkpoint counts were identical. No duplicate
records or extra checkpoints were added.

Trial run: `4a5269a8-e230-4a8e-841c-8c50cf2ba31a`. Full remainder run: `b9388b9c-946c-489e-8da6-a45764562a63`. Both are now
`completed`. These identifiers contain no source person values.

### Final reconciliation, all approved data/reference tabs

Both source reads matched for all 7,747 distinct source rows (15,494 total row
observations). Each populated tab's fingerprint matched the approved Stage 2
baseline; headers and emptiness were checked for the four empty sources. Source
values were not repaired or inferred. Every tab was reconciled before proceeding
to the next, in the approved dependency order.

| Source tab | Considered | Loaded | Quarantined | Domain table rows | Joined lineage rows | Committed checkpoints |
|---|---:|---:|---:|---:|---:|---:|
| 24.Reference List | 154 | 154 | 0 | 154 | 154 | 2 |
| 23.Staff | 20 | 20 | 0 | 20 | 20 | 1 |
| 4.Partner Organisation | 12 | 12 | 0 | 12 | 12 | 1 |
| 7.Learner Profile | 215 | 215 | 0 | 215 | 215 | 3 |
| 8.Family Contact | 286 | 286 | 0 | 286 | 286 | 3 |
| 9.Learner Sensitive Details | 215 | 215 | 0 | 215 | 215 | 3 |
| 10.Batch | 20 | 20 | 0 | 20 | 20 | 1 |
| 11.Enrolment | 220 | 220 | 0 | 220 | 220 | 3 |
| 1.Mobilisation Lead | 280 | 280 | 0 | 280 | 280 | 3 |
| 2.Lead Follow-up | 560 | 560 | 0 | 560 | 560 | 6 |
| 3.Mobilisation Activity | 810 | 810 | 0 | 810 | 810 | 9 |
| 5.Monthly Target | 162 | 162 | 0 | 162 | 162 | 2 |
| 6.Report & Meeting Log | 216 | 216 | 0 | 216 | 216 | 3 |
| 15.Standard Topic | 50 | 50 | 0 | 50 | 50 | 1 |
| 14.Master Programme Schedule | 120 | 120 | 0 | 120 | 120 | 2 |
| 16.Batch Schedule | 1320 | 1320 | 0 | 1320 | 1320 | 14 |
| 12.Fee Instalment | 660 | 660 | 0 | 660 | 660 | 7 |
| 13.Fee Payment | 597 | 597 | 0 | 597 | 597 | 6 |
| 21.Criterion Catalogue | 210 | 210 | 0 | 210 | 210 | 3 |
| 17.Learner Session Log | 1620 | 1620 | 0 | 1620 | 1620 | 17 |
| 18.Goal | 0 | 0 | 0 | 0 | 0 | 0 |
| 19.Goal Review | 0 | 0 | 0 | 0 | 0 | 0 |
| 20.Assessment Event | 0 | 0 | 0 | 0 | 0 | 0 |
| 22.Criterion Score | 0 | 0 | 0 | 0 | 0 | 0 |
| Total | 7747 | 7747 | 0 | 7747 | 7747 | 90 |

`loaded + quarantined = considered` holds per tab and in total. There are no
staging-only or unclassified source rows and no error-severity validation issues.
The four header-only source tables remain empty. No Model Guide records were
created. Source audit fields and all raw/formatted lineage remain private.

### Security and failure-log verification

- ids: 24 tables, RLS enabled on all 24. ids_import: four tables, RLS enabled
  on all four. Zero policies in both schemas.
- No table/view/sequence/function ACL grants in these private schemas to PUBLIC,
  anon, authenticated or service_role. No grants were introduced by the load.
- Both fee views retain security_invoker=true. Data API exposes only
  public,graphql_public, excluding ids and ids_import.
- Security advisor: zero WARN/ERROR findings; 28 INFO rls_enabled_no_policy
  findings, expected for the explicitly approved closed-access model.
- All 90 checkpoints are committed; maximum range is 100 rows. Both runs
  completed and all 7,747 source rows are classified loaded.
- Failure log: all 25 source-named tabs were read before and after loading and
  have zero failure entries, matching zero quarantines in every source. No
  failure-log write was needed; Scope notes was unchanged. No sensitive values
  were printed, put in the failure log or committed to Git.

Approved warning issues were retained without quarantine: 61 weekly-check
exceptions, 44 logs on Holiday/Cancelled sessions, 61 non-delivered sessions
with actual dates, three MOU-signed rows lacking dates and three MOU-date rows
without signed status. Total: 172 warning records, zero error records. These
are the approved source-audit annotations, not silent business-rule repairs.

### Measured stage timings and request counts

| Stage | Seconds / clock | Supabase HTTP requests | Google Sheets reads |
|---|---|---:|---:|
| Initial setup | Unmeasured | 0 | 0 |
| Trial source validation, two reads | 15.019 / orchestration wall, including metadata setup | 0 | 17 |
| Failure-log precheck | Unmeasured | 0 | 2 |
| Trial, including read-only recheck, bootstrap, per-tab accounting and replay | 52.517 / process monotonic | 24 | 0 |
| Remaining source validation, two reads | 168.144 / orchestration wall | 0 | 122 |
| Full-run initialization, loading and per-tab accounting | 548.065 / process monotonic | 191 | 0 |
| Final database/security verification | 7.330 / process monotonic | 6 | 0 |
| Final failure-log check | Unmeasured | 0 | 1 |
| Total measured service requests | Durations are not an end-to-end total | 221 | 142 |

The 221 Supabase requests comprise 91 data/finalization/replay transactions and
130 read-only requests. Of the 91, 88 are chunk-group transactions (including
the atomic three-checkpoint bootstrap), two finalize the runs, and one is the
verified no-duplicate replay. The 130 reads comprise 90 reconciliation queries,
23 accounting/verification queries, five project GETs, six API-config GETs,
five catalog reads and one advisor GET. No credits were measured or inferred.

Tool invocations are counted separately from HTTP requests within shell
processes. Setup: two shell calls and one environment-status call. Trial:
one execution shell and two polls. Full source manifest: one shell. Full-run
execution: one shell and 12 polls. Full-run monitoring: two
shell reads; verification preparation: one shell; private-file permissions: one
shell. Final database verification: one shell and one poll. Local snapshot
materialization/audit persistence: four patch-tool calls. Google metadata/cell
reads total 142, as above. Documentation preparation/commit/push and PR update
are recorded separately below; helper/setup/documentation timings were not
measured. Orchestration wrappers are not added to underlying invocation counts.

### Remaining limits

This was the approved **synthetic** dataset. Source values appear in SQL text
and may reach database/request logs; client-side sanitization is not a server-log
privacy guarantee. Real client data still requires a parameterised route and
verified database/parameter/error/request-log controls before loading. Those
controls were not inspected or changed. Local state durability across an
environment replacement is not established; any future missing/untrusted state
must follow explicit read-only reconciliation rather than blind replay.

Documentation publication: two shell tool invocations for preparation/switch and
commit/push, plus one GitHub PR-metadata update; elapsed time unmeasured.


## 2026-11-14 — Regenerated synthetic v2: approved implementation

Active workbook manifest: `source-audit-v2.json`, version
`regenerated-synthetic-v2-20261114`, 90,319 records across 24 data tabs; Model
Guide is documentation. Earlier source/count/load sections remain historical.
The regenerated workbook populates Goal, Goal Review, Assessment Event and
Criterion Score, expands Learner Session Log to 12,139 records, and adds 11
Reference List options (165 total).

The additive migration `20261114102844_align_goal_review_scales.sql` replaces
only `ids.goal_review.goal_review_check`: SMART becomes 1–5; Functional Learning
and Hospitality become 0–5. Lower limits, nullable scores and other sections
are unchanged. The demo scale was widened to match this dataset; the real
client scale is to be confirmed. Applied migrations are not edited.

Monthly Target keeps its date column. Exact YYYY-MM source text becomes
YYYY-MM-01 deterministically; original text remains in source-row raw lineage.
All 471 weekly-check placement warnings, 61 non-delivered sessions with actual
dates and 328 Holiday/Cancelled logs are retained, not quarantined. No extra
reference options are inferred. IQ, height and weight remain as supplied; their
necessity, meaning, units and access remain an open sensitivity question.

This load uses synthetic data. Source values appear in SQL statement text and
could reach database or request logs. Before real client data is loaded, use a
parameterised route with database/request/parameter/error log controls verified.
No transport change or server-log privacy guarantee is claimed here.

Local validation after fixing the synthetic Reference List fixture: 56/56
loader tests passed in 24.105 seconds, including real PostgreSQL 17.11 scale
boundaries (both score fields, retained lower limits, 5 valid, 5.01/6 invalid),
month conversion/raw lineage, atomic rollback, replay, concurrency and lost
response recovery. `python scripts/validate_local.py` also passed: all three
migrations, schema contract, RLS/grants, 186 FKs and five concurrency checks.
Only invented fixtures were seeded into a disposable, network-isolated local
container. Hosted migration/load/security verification is pending. Setup and
separate schema-validator elapsed time were unmeasured; no credits inferred.
