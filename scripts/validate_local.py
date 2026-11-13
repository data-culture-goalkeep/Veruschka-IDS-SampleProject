#!/usr/bin/env python3
"""Validate migrations only in a new, network-isolated local Postgres container."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
IMAGE = 'postgres:17.11-bookworm@sha256:665dc7b37ac52a17e298511414c21d23ffa4e6a6ef6225b3e5d59c7afb35e994'
DOCKER = ['docker', '--host=unix:///var/run/docker.sock']


def main():
    # Avoid inherited selectors or remote credentials redirecting the validator.
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(('SUPABASE_', 'PG', 'DOCKER_HOST', 'DOCKER_CONTEXT', 'DOCKER_TLS', 'DOCKER_CERT_PATH'))}
    name = 'veruschka-local-' + uuid.uuid4().hex[:12]

    def run(args, text=None, check=True):
        p = subprocess.run(args, input=text, text=True, capture_output=True, env=env)
        if check and p.returncode:
            raise RuntimeError(p.stderr.strip() or p.stdout.strip())
        return p

    def query(text):
        return run(DOCKER + ['exec', '-i', name, 'psql', '-X', '-v', 'ON_ERROR_STOP=1',
                             '-U', 'postgres', '-d', 'ids_local_validation'], text).stdout

    try:
        run(DOCKER + ['info'])
        run(DOCKER + ['run', '--detach', '--rm', '--name', name, '--network', 'none',
                      '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', '-e', 'POSTGRES_DB=ids_local_validation', IMAGE])
        for _ in range(60):
            if run(DOCKER + ['exec', name, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres',
                             '-d', 'ids_local_validation'], check=False).returncode == 0:
                break
            time.sleep(0.25)
        else:
            raise RuntimeError('Local Postgres failed to become ready')
        # Minimal compatibility fixture, not an emulation of the Supabase services.
        query('create role anon; create role authenticated; create role service_role bypassrls; '
              'create schema auth; create table auth.users(id uuid primary key);')
        migrations = sorted((ROOT / 'supabase/migrations').glob('*.sql'))
        if not migrations:
            raise RuntimeError('No migration files')
        for migration in migrations:
            query(migration.read_text())
        query(run([sys.executable, str(ROOT / 'scripts/seed_dummy.py')]).stdout)
        query((ROOT / 'tests/schema_contract.sql').read_text())
        print(json.dumps({'result': 'PASS', 'postgres': '17.11', 'migrations': [p.name for p in migrations],
                          'scope': 'local Docker only; no hosted access',
                          'checks': 'schema shape, constraints, parent updates, fee math, lineage, RLS, grants, functions, approved exceptions'}))
    finally:
        run(DOCKER + ['rm', '-f', name], check=False)


if __name__ == '__main__':
    main()
