# Stage 3 validation — 2026-11-13

## Result

The original Stage 3 result is retained below. The current two-migration review-fix
run and both review checklists are recorded in the dated section at the end.

`python scripts/validate_local.py` passed on an isolated PostgreSQL **17.11**
container using only invented dummy records. Migration file:
`20261113125204_private_ids_schema.sql`. No hosted migration was applied.

| Check | Result |
|---|---|
| 24 domain + 4 import/audit tables | Pass |
| RLS enabled on all 28 tables; zero policies | Pass |
| No anon/authenticated/service_role access to either schema, tables, views or private functions | Pass |
| Private invoker functions with fixed search_path; two security-invoker fee views | Pass |
| Index coverage for every FK | Pass |
| All 154 authoritative options across 52 lists accepted by seed | Pass |
| One lead per non-null learner; multiple null links accepted | Pass |
| Missing/blank Aadhaar rejected | Pass |
| docs_provided boolean; optional assessment session; empty Activity next date | Pass |
| Orphan parent IDs, wrong option groups, duplicate sessions and invalid session numbers rejected | Pass |
| Learner/contact and enrolment/session batch consistency, including parent updates | Pass |
| Assessment/criterion version mismatch, used-rubric mutation and excessive criterion scores rejected | Pass |
| Goal review scales/milestones/Other-pathway requirements and ILS-only goals | Pass |
| Positive payments/refunds; oldest-due allocation; partial payment; excess credit | Pass |
| Holiday dates/logs, off-rule weekly checks, MOU mismatch, unknown text and null scores remain accepted | Pass |
| Shared family Auth identity accepted; duplicate Staff Auth identity rejected | Pass |
| Import project allowlist and per-run row identity uniqueness | Pass |
| Warning records do not force quarantine | Pass |
| Actual reads under anon/authenticated fail | Pass |

The validator uses the local Docker Unix socket explicitly, strips inherited
database selectors/credentials, publishes no ports and runs with `--network none`.
It removes its disposable container in a finally block. Image:

```
postgres:17.11-bookworm@sha256:665dc7b37ac52a17e298511414c21d23ffa4e6a6ef6225b3e5d59c7afb35e994
```

Supabase CLI **3.1.0** created the migration using `migration new`; command help
and the current CLI v3 changelog were read first. CLI state/npm cache stayed in
workspace scratch directories, not the repository. Package versions and the
Postgres image digest are pinned. Python scripts use only the standard library.

## Read-only source evidence

Stage 2 baseline: 25 tabs, 7,747 data/reference rows. Repeat reads matched all
7,747 rows. Metadata/checksums are in source-audit.json; raw values are not in Git.
Fresh Stage 3 reads found 215 converted leads/280 total, zero repeated non-null
learner links, and 215/215 nonblank Aadhaar values. Source files were not edited.

## Hosted baseline and limits

Read-only hosted catalog check: zero public tables; ids/ids_import absent.
Performance advisor: zero findings. Security advisor: two existing warnings on
public.rls_auto_enable(), executable SECURITY DEFINER for anon/authenticated;
recorded in handover.md and not modified here.

Local Auth support is a minimal auth.users(id) fixture and role names. This test
does not run PostgREST, Auth services, hosted platform event triggers or the
Supabase advisor engine. Hosted API exposure and post-application advisors remain
mandatory after a separately approved migration application. The schema is not
claimed to be advisor-clean on an environment where it has not been applied.

No source load, parser implementation, Google failure-log Sheet, remote application
or PR merge was performed. Schema-only work does not authorize a later loader.

## 2026-11-13 — GitHub P1 and chat-review fixes

Both local migrations passed together:

- `20261113125204_private_ids_schema.sql` (original, unchanged)
- `20261113125216_review_integrity_and_privacy_fixes.sql` (additive review fixes)

`python scripts/validate_local.py` runs the original contract, the review
regressions, a committed Staff/Reference bootstrap transaction and real concurrent
database sessions. The test database remains a disposable, network-isolated
PostgreSQL 17.11 container; no Supabase DDL or source writes are performed.

| Review | Finding / correction | Verification |
|---|---|---|
| GitHub P1, comment 4562558469, original SQL lines 56–57 | Bind source row to chunk sheet and first/last bounds; bind file to run | Wrong sheet and wrong file rejected with 23503; below/above range and spoofed bounds rejected with 23514; valid boundary rows accepted |
| Chat: EXECUTE hardening | Narrow revoke from PUBLIC, anon, authenticated on existing public.rls_auto_enable() | ACL checks deny inherited/direct access; owner retains access; local event trigger still enables RLS |
| Chat: unknown fee obligation | Preserve NULL credit when no instalments exist | NULL due/balance/credit asserted, with and without a payment |
| Chat: rubric provenance | Compare definition/scoring fields only | Source-row lineage, created/updated timestamps and actors update successfully; wording/weight/scoring changes remain rejected once used |
| Chat: concurrency | Composite FKs replace relational snapshot scans | Parent-contact change blocks behind an uncommitted child and then fails under READ COMMITTED and REPEATABLE READ; no wrong-learner relationship survives |
| Chat: remaining existence check | Definition updates require READ COMMITTED; scores hold SHARE on catalogue | Concurrent score commits; waiting definition rewrite fails; REPEATABLE READ and SERIALIZABLE definition updates explicitly fail with 0A000 |
| Chat: Staff/Reference cycle | Defer FKs in one bootstrap transaction, preserving nonnull actors | Real commit, actor readback, then committed dummy cleanup; no source audit fields replaced with null |
| Chat: redundant indexes | Remove indexes covered by compatible unique-key prefixes | Original FK-index coverage test still passes; no exact duplicate nonunique/unique indexes remain |
| Chat: ER completeness | Include attendance reference, audit chunk scope and all new composite FKs | Validator compares all live local FK edges with ER; model manifest columns/types/nullability also match the local catalog |

The concurrency suite has three synchronized two-session races and two isolation
rejection cases. It observes a real database lock wait before releasing the
competing transaction; it does not rely on a fixed sleep to assume concurrency.
Catalog/diagram agreement covers all 186 FKs; the schema still has 28 tables,
RLS on every table, zero policies and no API-role object access.
Statements have bounded waits and the harness closes sessions/removes the
container even on failure.

The compatibility fixture now includes a local public.rls_auto_enable event
trigger and intentionally broad global default grants. This verifies that the
explicit object revokes close the model despite inherited defaults. The fixture
is not a complete Supabase platform or PostgREST deployment.

The previous trigger-error expectations changed from 23514 to 23503 where the
same invalid relationships are now rejected by declarative FKs. Constraints were
not loosened to make the original tests pass. NULL ratings and approved source
exceptions remain accepted.

Hosted limits remain: the function revoke is only in an unapplied SQL file; no
claim is made that live advisor warnings have cleared. Hosted migration history,
API exposure and platform behavior must be verified only during a separately
approved application. No real source records were used in these local tests.

## 2026-11-13 — PR #2 fixes: local integration validation and logging boundary

The planned load uses **synthetic data**. Source values are embedded in SQL
statement text and **could reach database or request logs**. The transport was
intentionally not changed. For **real client data**, the loader must first use a
**parameterised route with database, parameter, error and request-log controls
verified**. Client-side error sanitization alone is insufficient. No hosted log
configuration was inspected and no real-data deployment clearance is claimed.

The current loader suite is run with:

```sh
python -m pip install --target work/test-deps --no-cache-dir -r tests/requirements-loader-test.txt
PYTHONPATH=work/test-deps python -m unittest discover -s tests -p 'test_*.py' -v
```

Parser import/version mismatch now fails test collection. A negative test starts
an isolated Python without site packages to confirm missing-parser failure.
Unit regressions cover total/partial state loss, corruption, mismatched generations,
attempt ownership, same-process and cross-process exclusion, and mutation during
preflight. Recursively frozen snapshots are used for all validation and SQL.

Eight real PostgreSQL integration cases use a disposable, network-isolated,
digest-pinned 17.11 container. They check rollback of data/lineage/checkpoints/run
registration on mid-chunk errors and deferred bootstrap failures, a successful
174-row bootstrap preserving audit actors, duplicate-free replay, changed chunk
rejection at both Python and SQL layers, tampered-lineage rejection, exclusive
concurrent execution, and committed-but-lost-response recovery. Recovery verifies
data through READ ONLY transactions; reconciliation itself performs zero database
writes and does not automatically resume loading.

No source snapshot or seed script is used by these tests. The legacy
scripts/validate_local.py harness invokes seed_dummy.py, so it is excluded from
this no-seed stage; its earlier Stage 3 results remain historical evidence, not a
claim of rerun. No hosted request, migration, grant, data load or merge occurred.
Local PostgreSQL tests do not establish hosted Management API response semantics
or infrastructure log privacy. The persistent state filesystem and shared locking
path must be provisioned before a future approved application.

Final result for this revision: **53 tests passed** (45 unit/parser/control tests
and eight PostgreSQL integration tests); zero skips. `git diff --check` passed.
The throwaway container and per-case databases were removed after testing.

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


## 2026-11-14 — Regenerated workbook reload stopped at inspection gate

The user authorized a worker-route reload of the new synthetic workbook
`1ZNF0oGXt06kX5ezohN1HHO4--Z9fsiDVm-D7JXlEooc` into the allowed project
`uzofrrrtwqjmtytrbqfr` only, with a hard stop for schema mismatches or more
than 1% quarantine candidates in any tab. This section records a blocked
read-only inspection, not a reload or complete workbook validation.

Preflight used latest main `c3eacf54096941e3c0c3e1a4386980a09b2d98f0`.
The loader entered main with PR #2, commit `1669f8954bf64314e52cb2ebab918fc4665a137d`;
its existing source allowlist/row manifest still targets the first workbook.
A new versioned source manifest and first-run reconciliation were not created
because inspection hit the mandatory stop gate first. No allowlist was bypassed.

The worker confirmed Veruschka-IDS-SampleProject is ACTIVE_HEALTHY and all
28 ids/ids_import tables are empty. Migration history remains:
20261113125204 private_ids_schema and
20261113125216 review_integrity_and_privacy_fixes.
RLS remains enabled on all 28, with zero policies and no private-model object
grants to PUBLIC, anon, authenticated or service_role. The read-only advisor
reported zero WARN/ERROR and 28 expected RLS-with-no-policy INFO findings.

### Stop finding

The first 250 rows inspected in 19.Goal Review contain **60 distinct invalid
rows**, with **102 field-level rating violations**. The source Goal rows were
joined in memory to determine each review's section. The approved schema limits
Functional Learning and Hospitality faculty/family scores to 0–3; scores of 4
appear in the new source.

The Goal Review grid has 4,457 rows. After its two title/header rows, there
can be **at most 4,455 data rows**. Therefore the 60 already identified invalid
rows alone represent at least **1.3468%** of that tab. This lower bound proves
the stop threshold is exceeded without claiming that grid size is the actual
record count. Full tab counting and full violation enumeration were stopped.

Affected worksheet row references found so far:
13, 14, 19, 20, 31, 32, 37, 38, 50, 54, 55, 56, 60, 61, 62, 85, 86, 91, 92, 103, 104, 109, 110, 122, 127, 128, 132, 133, 134, 156, 157, 158, 162, 163, 164, 170, 175, 176, 180, 181, 182, 194, 199, 200, 205, 206, 224, 227, 228, 229, 230, 233, 234, 235, 236, 242, 246, 247, 248, 252.

No ratings were clamped, remapped or silently repaired. The source workbook
and the database were not changed. These are quarantine candidates only:
nothing was staged or quarantined in the database or failure log.

### Scope actually inspected

Metadata confirms 25 source tabs. The expected header ranges in all 24
data/reference tabs match the existing manifest. This is not a complete
schema/value audit, including columns outside the inspected header ranges.

| Source tab | Distinct data rows inspected | Completeness |
|---|---:|---|
| 18.Goal | 100 | Partial |
| 19.Goal Review | 250 | Partial; stop threshold proven |
| 20.Assessment Event | 100 | Partial |
| 21.Criterion Catalogue | 210 | Bounded read; full source inventory not certified |
| 24.Reference List | 165 | Bounded read; 11 new options observed |
| Total | 825 | Partial workbook inspection |

The 11 additional observed Reference List IDs are:
assessment_stage.END; criterion_rating.0, criterion_rating.1,
criterion_rating.2, criterion_rating.5; faculty_rating.NEEDS_SUPPORT,
faculty_rating.CONSISTENT, faculty_rating.INDEPENDENT;
family_rating.RARELY, family_rating.USUALLY, family_rating.ALWAYS.
Adding dropdown options does not override the numeric CHECK limits.

Workbook tab gids differ from the previous file and require a fresh manifest;
business-ID preservation and all uniqueness/FK/rubric/batch/contact checks were
not fully verified. No final row counts are inferred from grid dimensions.

### Load/reconciliation outcome and limits

All 28 destination tables remain empty: considered-for-load=0, loaded=0,
quarantined=0, import runs=0, lineage=0, checkpoints=0. No first-run state was
provisioned and no new import version tag was activated. No reload, seed,
failure-log edit, schema/grant change or merge occurred. The complete per-tab
load reconciliation and post-load verification are not applicable.

IQ, height and weight were not loaded or modified. They remain an open
sensitivity question for handover: how should these synthetic measurements be
handled, and what consent/access/retention rules would apply to real client data?
If loading is approved later, values must be retained as supplied, not inferred.

The read-only stage used seven worker HTTP requests (one project GET,
five database-query reads and one security-advisor GET), four Sheets reads
(metadata, headers and two bounded rule probes), four shell invocations and
one shell poll. Environment status was read once. One private scratch patch
succeeded; a later patch to materialize the extended probe failed validation
before changing that file and was not retried. The stop-threshold calculation
used already-read in-memory data; no additional source reads followed it.
Stage elapsed timings were not instrumented and are **unmeasured**. No credits
are inferred from requests or tool calls. Documentation publication calls are
separate from these inspection counts.

The user must decide whether to correct the source scores, explicitly approve
a revised rating model through reviewed schema changes, or explicitly approve
a quarantine rate above the specified threshold. Until then, do not load.
