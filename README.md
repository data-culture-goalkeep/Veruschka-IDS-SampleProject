# Veruschka IDS sample project

Private, audited data model for the Veruschka Foundation's synthetic sample build.
Synthetic identity, financial and medical fields are treated as sensitive.

**Stage 3: PR review only. No hosted migration application or source loading is
authorized.** The only allowed hosted project is `uzofrrrtwqjmtytrbqfr`.

- [Model and approved rules](docs/model.md)
- [Every model field and relationship](docs/fields.md)
- [Full ER diagram](docs/er-diagram.mmd)
- [Authoritative dropdown configuration](config/reference-options.json)
- [Dated handover, source exceptions and open questions](docs/handover.md)
- [Local verification results and limits](docs/validation.md)
- [Working instructions](AGENTS.md)

Run local migration, dummy-seed and integrity/security checks:

```sh
python scripts/validate_local.py
```

Requires Python 3 and the local Docker daemon. The pinned Postgres image must be
available or retrievable. This creates and removes a network-isolated disposable
container, exposes no ports, and does not use remote database credentials.

`python scripts/seed_dummy.py` emits invented dummy SQL to stdout. It never
connects to a database. The validation harness consumes it only in its local
container; the seed is not automatically run by Supabase.

Create future migration files with the pinned Supabase CLI, after checking help:

```sh
npx --yes supabase@3.1.0 migration new --help
npx --yes supabase@3.1.0 migration new descriptive_name
```

In restricted workspaces set `SUPABASE_HOME` and npm's cache to writable scratch
directories. Do not change HOME or put tokens in the repository. Do not link,
push/apply a migration, configure API exposure or merge a PR under Stage 3 approval.

Use `.env.example` only as a variable-name template. Configure real credentials
in environment Secret settings; never paste them into chat or commit them. Raw
extracts and CSVs stay outside Git. Read the handover before continuing stages.
