#!/usr/bin/env python3
"""Validate migrations only in a new, network-isolated local Postgres container."""
import json
import importlib.util
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
        return run(DOCKER + ['exec', '-i', name, 'psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1',
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
        query((ROOT / 'tests/supabase_compat.sql').read_text())
        migrations = sorted((ROOT / 'supabase/migrations').glob('*.sql'))
        if not migrations:
            raise RuntimeError('No migration files')
        for migration in migrations:
            query(migration.read_text())
        spec = json.loads((ROOT / 'docs/model-spec.json').read_text())
        types = {'integer':'int4','boolean':'bool'}
        expected = {}
        for table in spec['tables']:
            for field in table['fields'] + table.get('integrity_fields', []):
                expected[table['name'] + '.' + field['name']] = [
                    types.get(field['type'], field['type']), not field['nullable']]
            expected[table['name'] + '.source_row_id'] = ['uuid', False]
        actual = json.loads(query("""select json_object_agg(c.relname || '.' || a.attname,
            json_build_array(t.typname,a.attnotnull))
            from pg_attribute a join pg_class c on c.oid=a.attrelid
            join pg_namespace n on n.oid=c.relnamespace join pg_type t on t.oid=a.atttypid
            where n.nspname='ids' and c.relkind='r' and a.attnum>0 and not a.attisdropped;"""))
        if expected != actual:
            raise AssertionError('Model manifest differs from SQL columns/types/nullability')
        er = (ROOT / 'docs/er-diagram.mmd').read_text()
        fks = json.loads(query("""select json_agg(json_build_object(
            'child',cn.nspname || '.' || cc.relname,'parent',pn.nspname || '.' || pc.relname,
            'columns',array(select a.attname from unnest(f.conkey) with ordinality k(attnum,ord)
                join pg_attribute a on a.attrelid=f.conrelid and a.attnum=k.attnum order by k.ord)))
            from pg_constraint f join pg_class cc on cc.oid=f.conrelid
            join pg_namespace cn on cn.oid=cc.relnamespace join pg_class pc on pc.oid=f.confrelid
            join pg_namespace pn on pn.oid=pc.relnamespace
            where cn.nspname in ('ids','ids_import') and f.contype='f';"""))
        def er_name(name):
            return name.removeprefix('ids.').replace('.', '_')
        for fk in fks:
            parent = er_name(fk['parent'])
            child = er_name(fk['child'])
            label = ', '.join(fk['columns'])
            if not any(line.startswith('    ' + parent + ' ') and
                       line.endswith(' ' + child + ' : "' + label + '"') for line in er.splitlines()):
                raise AssertionError('ER diagram missing FK: ' + repr(fk))
        query(run([sys.executable, str(ROOT / 'scripts/seed_dummy.py')]).stdout)
        query((ROOT / 'tests/schema_contract.sql').read_text())
        query((ROOT / 'tests/review_regressions.sql').read_text())
        query((ROOT / 'tests/bootstrap.sql').read_text())
        module_spec = importlib.util.spec_from_file_location('local_concurrency', ROOT / 'tests/concurrency.py')
        concurrency = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(concurrency)
        races = concurrency.run(DOCKER + ['exec', '-i', name, 'psql', '-X', '-qAt',
                                '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose',
                                '-U', 'postgres', '-d', 'ids_local_validation'], env, query)
        print(json.dumps({'result': 'PASS', 'postgres': '17.11', 'migrations': [p.name for p in migrations],
                          'scope': 'local Docker only; no hosted access',
                          'concurrency_checks': races,
                          'documented_foreign_keys': len(fks),
                          'checks': 'schema shape, constraints, parent updates, fee math, lineage, RLS, grants, functions, approved exceptions'}))
    finally:
        run(DOCKER + ['rm', '-f', name], check=False)


if __name__ == '__main__':
    main()
