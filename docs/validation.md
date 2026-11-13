# Stage 3 validation — 2026-11-13

## Result

`python scripts/validate_local.py` passed on an isolated PostgreSQL **17.11**
container using only invented dummy records. Migration file:
`20261113095327_private_ids_schema.sql`. No hosted migration was applied.

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
