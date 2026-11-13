# Veruschka IDS working rules

- Allowed hosted Supabase project only: `uzofrrrtwqjmtytrbqfr`.
- Never access `pcxicqcroyrmysqgmmtp` or projects in the client's organisation.
- Stage 3 is approved only through opening a PR. Do not apply migrations remotely,
  load source data, configure access, create Auth users, or merge without explicit approval.
- Treat synthetic identity, medical, income and contact fields as sensitive.
  Never commit source rows, raw extracts, CSVs, credentials or environment values.
- Read `docs/model.md`, `docs/handover.md` and `docs/model-spec.json` before changes.
  Retain dated history; add new decisions rather than erasing earlier findings.
- Use a feature branch from latest main. Create migrations with the pinned Supabase
  CLI (`supabase migration new`); never edit migrations already applied anywhere.
- Keep `ids` and `ids_import` outside Data API exposed schemas. Enable RLS on
  every table; add no policies or grants without an approved access model.
- Preserve source IDs and raw values. Never infer blank values, merge people by
  name, repair source anomalies silently, or turn missing attendance into absence.
- Local validation: `python scripts/validate_local.py`. It uses only the local
  Docker Unix socket, no published ports or remote database credentials.
- Seed data must be invented dummy data, not copied source people or rows.
- Any later loader must allowlist the project and approved tabs/ranges, record
  source/run/row lineage, use idempotent chunks, and stop on failed, declined,
  cancelled or uncertain writes. Verify uncertain outcomes before any retry.
- GitHub PR creation is authorized; merging and hosted migration application are not.
