# Stage 4 worker SQL adapter — review before any load

2026-11-13. Implementation and offline testing are approved. Hosted data loading,
seed execution and merging this PR are not authorized. Branch is based on latest
main `51d0c92139ce385c0f93085d4e5a8b03185d8446` (which already includes PR #1).

## Read-only source trial

124 distinct selected source rows were read twice through the Sheets connector;
both reads matched, including raw types and formatting metadata. 124 transformed;
zero would be quarantined after correcting strict time-text parsing. The initial
parser rejected start/end time strings on Batch Schedule rows 31, 33, 60, 64;
the final parser accepts only explicit HH:MM[:SS[.ffffff]] time strings, without
using cell formatting to infer types. Date serials remain dates; booleans with
stale date formats remain booleans. Twelve stale temporal formats were ignored;
168 null fields were preserved. No identifiers or source values are recorded here.

| Approved exception reason | Warning instances |
|---|---:|
| weekly_check_first_held_rule | 61 |
| logs_on_holiday_or_cancelled | 44 |
| non_delivered_with_actual_date | 4 |
| mou_signed_missing_date | 3 |
| mou_date_without_signed_status | 3 |
| Total | 115 |

These are annotations from the approved Stage 2 row manifest, not a fresh global
recomputation of the weekly-check rule or a full foreign-key validation. The
124-row selection is not a dependency-complete hosted-load manifest.

Exact trial rows:
- Learner Profile, Enrolment, Master Programme Schedule: 3–5 in each.
- Partner Organisation: 4, 5, 8, 9, 12, 13.
- Batch Schedule: 31, 33, 60, 64.
- Learner Session Log: the 61 weekly_check_first_held_rule rows and all 44
  logs_on_holiday_or_cancelled rows in source-audit.json (105 distinct rows).

Raw/typed cell snapshots and transformed results remained in ignored private
work/ files and were never printed or committed. No failure-log writes occurred;
all 25 source-log tabs were read back and contained zero data entries. The Scope
notes tab was not changed. No database requests were issued during this stage.

## Source intake and approval contract

`scripts/load_ids.py` is a standard-library transformer and worker SQL adapter.
Its CLI only performs an offline dry-run; it has no apply flag. Input is a private
JSON object containing `headers` keyed by exact source tab title and `rows` with
`tab`, `row`, and bounded Sheets `CellData` in source-column order. Example shape,
using invented cells only:

```json
{"headers":{"4.Partner Organisation":["partner_organisation_id (PK)"]},
 "rows":[{"tab":"4.Partner Organisation","row":3,
          "cells":[{"userEnteredValue":{"stringValue":"invented-example"}}]}]}
```

The short example illustrates the shape; real headers must match the complete
checked-in source header list, otherwise intake stops. Formula cells, unknown
headers, out-of-range rows, missing required values and ambiguous types stop
intake. No source values, SQL, provider error bodies or tracebacks are printed.
The caller must preserve raw serial/display values, pad missing cells to the
approved width, and supply two independently read complete snapshots. Empty
source tabs require header/emptiness checks by that caller; the adapter never
manufactures their records. Model Guide is documentation only.

Future application requires a separately approved immutable `Approval` containing
project, source, run UUID, canonical snapshot SHA-256 and exact permitted row
ranges, with `writes_authorized=True`. That flag is a gate, not an authorization
to set it in this stage. The approved source is the current workbook only, not its
backup. Every supplied transform is independently regenerated from raw cells;
forged field names, records, sheet IDs or warning annotations are rejected.

The orchestrator must first verify the full source inventory and approved
exceptions against the Stage 2 baseline, freeze the manifest, check referenced
Auth IDs without creating accounts, and obtain load approval. Changed source
content or new exceptions requires review rather than applying historical row
annotations to a different workbook state. This module is the SQL adapter, not
a new credentialed Google Sheets extraction service.

## SQL and execution contract

- `Worker` uses only the allowlisted project on api.supabase.com, with inherited
  proxy/CA trust and the environment token. No redirect, retry, alternative route
  or Supabase connector fallback exists. It checks project identity/health,
  exposed schemas, migration versions, 28 RLS tables, zero policies and closed
  model object ACLs before loading. No grants, DDL or API settings are changed.
- `Loader.load(rows, repeated_rows)` denies missing approval, differing source
  reads, duplicate rows, scope or snapshot mismatches before writing. Supply an
  acknowledged failure sink and a persistent `Journal` outside the repository.
  Its canonical filename must be <run-uuid>.json, shared by every worker for
  that run. Even first execution requires an explicit read-only reconcile call;
  load never initializes missing state automatically.
- Dependency order is fixed. Reference List is inserted before Staff in one
  deferred transaction; all 174 bootstrap rows are required when either source
  participates. Each checkpoint covers at most 100 contiguous rows from one tab.
  Other oversized chunks split deterministically before any write. A single row
  or complete atomic bootstrap exceeding the 512,000-byte request cap stops.
- Every transaction takes a project-wide advisory lock, fixes search_path and
  READ COMMITTED isolation, and sets timeouts. Business rows, raw lineage,
  approved warning codes and committed checkpoints are atomic. Foreign keys
  become immediate before COMMIT. Source audit timestamps/actors are preserved.
- Run, chunk and lineage identities are deterministic. A committed checkpoint
  must match scope, payload hash, exact lineage, typed business fields, output
  counts and warning set before it is skipped. Existing unrelated keys conflict;
  business records are never silently overwritten or ignored.
- Completion reconciles source and checkpoint counts and dispositions for the
  run, then marks it completed. Receipts are returned only after COMMIT. A missing
  or malformed receipt stops; failed transactions produce no accepted checkpoint.
- Before each write, a private, fsync'd journal records in_flight. Only an exact
  commit receipt clears it. A timeout, exception, malformed receipt or process
  crash leaves the run blocked across restarts. An exclusive OS lock covers the
  entire execution, and only the owning attempt UUID can clear its marker.
  A stopped instance cannot resume.
  Do not delete/change the journal to retry: first perform separately authorized
  read-only reconciliation of the exact run/chunk IDs, hashes and database rows.
  Use Loader.reconcile(rows, repeated_rows, authorized=True) only under separate
  operator approval after prior requests have settled. It issues bounded READ
  ONLY transactions, verifies any committed chunks and missing-chunk lineage,
  and records first/resume mode locally; it never automatically calls load.
- The failure sink receives only source file ID, tab/range and an allowlisted
  reason code. It must write those three fields through the established Sheets
  connector and return exactly True only after verified acknowledgement. False,
  declined, missing acknowledgement or exceptions stop the run. SQL/database
  DETAILS must never be forwarded. The Google credential is not sent to Supabase.

## Tests and limits

Install the pinned optional parser into ignored scratch storage, then run:

```sh
python -m pip install --target work/test-deps --no-cache-dir -r tests/requirements-loader-test.txt
PYTHONPATH=work/test-deps python -m unittest discover -s tests -p 'test_*.py' -v
```

Unit tests use invented cells and fake transports; integration tests use only
a throwaway local PostgreSQL container with invented fixtures. They exercise approval/scope/hash
checks, input typing, bounded chunks, atomic bootstrap order, replay SQL, commit
receipts, durable uncertainty, privacy, failure-log acknowledgement and PostgreSQL
SQL/PLpgSQL syntax parsing across all 24 target tables. The pinned parser is
mandatory. Integration tests exercise real transaction/replay/rollback behavior
locally; no hosted database is contacted and no seed runs.

Local integration tests establish the covered PostgreSQL behavior but do not
prove remote Management API behavior or infrastructure log controls. Review this PR before any load; no live ingestion success
is claimed. The existing seeded schema validator was intentionally not run during
this no-database-write/no-seed stage.


Before first execution, and after missing/corrupt state or uncertainty, provision
a private persistent state location outside the checkout and explicitly authorize
read-only reconciliation. All processes/hosts must use the same state and lock
files on a filesystem with reliable shared flock semantics; choosing another
state directory is not an approved bypass. fsync provides crash durability, not
protection against deletion or volume loss: such loss always requires reconciliation.
A new Loader instance is required after a stopped attempt.

The current route is for the approved synthetic dataset. Inline source values
can enter database/request logs; real client data requires a parameterised route
and verified log controls first. See the dated handover/validation sections.
