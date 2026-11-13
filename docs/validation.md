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
