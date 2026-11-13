#!/usr/bin/env python3
"""IDS source transformer and reviewed worker SQL adapter; CLI is dry-run only.

No credentials or SQL are printed. Applying requires calling Loader with an
explicit Approval, a fixed snapshot and a failure sink after separate approval.
"""
from __future__ import annotations
import argparse
from contextlib import contextmanager
import fcntl
from types import MappingProxyType
from dataclasses import dataclass
from datetime import datetime, timedelta, time
from decimal import Decimal, InvalidOperation
import hashlib
import json
import os
import tempfile
from pathlib import Path
import re
import urllib.request
import uuid
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
PROJECT = 'uzofrrrtwqjmtytrbqfr'
SOURCE = '1oaKtbiklzsDqS02Y4kXmu9BXMzdHxBEJVsirt91VSGQ'
MAX_ROWS = 100
MAX_BYTES = 512_000
ORDER = [24, 23, 4, 7, 8, 9, 10, 11, 1, 2, 3, 5, 6, 15, 14, 16, 12, 13, 21, 17, 18, 19, 20, 22]
SPEC = json.loads((ROOT / 'docs/model-spec.json').read_text())
AUDIT = json.loads((ROOT / 'docs/source-audit.json').read_text())
TABLES = {t['source_tab']: t for t in SPEC['tables']}
TABS = {t['tab']: t for t in AUDIT['tabs']}
CODES = {'SCOPE_MISMATCH', 'NOT_APPROVED', 'HEADER_CHANGED', 'ROW_INVALID',
         'FORMULA_FOUND', 'TYPE_INVALID', 'REQUIRED_VALUE', 'SOURCE_CHANGED',
         'PAYLOAD_TOO_LARGE', 'WRITE_FAILED_OR_UNCERTAIN', 'RECEIPT_INVALID',
         'PREFLIGHT_FAILED', 'FAILURE_LOG_FAILED', 'SNAPSHOT_INCOMPLETE',
         'RECONCILIATION_REQUIRED', 'RUN_LOCKED', 'ATTEMPT_CONFLICT'}

class StopLoad(Exception):
    """Only allowlisted codes cross logging boundaries; never provider DETAILS."""
    def __init__(self, code):
        self.code = code if code in CODES else 'WRITE_FAILED_OR_UNCERTAIN'
        super().__init__(self.code)

def freeze(value):
    if isinstance(value, dict): return MappingProxyType({k:freeze(v) for k,v in value.items()})
    if isinstance(value, list): return tuple(freeze(v) for v in value)
    return value

def thaw(value):
    if isinstance(value, (dict, MappingProxyType)): return {k:thaw(v) for k,v in value.items()}
    if isinstance(value, (tuple, list)): return [thaw(v) for v in value]
    return value

def private_snapshot(value):
    # Copy through JSON, then recursively freeze: no caller-owned mutable objects.
    return freeze(json.loads(canonical(value)))

def canonical(value):
    return json.dumps(thaw(value), sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False)

def sha(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()

def literal(value):
    text = str(value)
    if '\x00' in text: raise StopLoad('ROW_INVALID')
    return "'" + text.replace("'", "''") + "'"

def ident(value):
    if not re.fullmatch('[a-z_][a-z_0-9]*', value): raise StopLoad('SCOPE_MISMATCH')
    return '"' + value + '"'

def json_sql(value):
    return literal(canonical(value)) + '::jsonb'

def block(body):
    # A source value can contain any dollar delimiter, even inside a SQL literal.
    tag = '$ids_loader$'
    while tag in body: tag = '$ids_' + uuid.uuid4().hex + '$'
    return 'DO ' + tag + '\nBEGIN\n' + body + '\nEND\n' + tag + ';'

def parse_cell(cell, field):
    value = cell.get('userEnteredValue', {})
    if 'formulaValue' in value: raise StopLoad('FORMULA_FOUND')
    if not value or value.get('stringValue') == '':
        if not field['nullable']: raise StopLoad('REQUIRED_VALUE')
        return None
    if len(value) != 1: raise StopLoad('TYPE_INVALID')
    kind = field['type']; v = next(iter(value.values()))
    try:
        if kind == 'boolean':
            if type(v) is not bool: raise ValueError()
            return v
        if kind in ('numeric', 'integer'):
            if type(v) is bool: raise ValueError()
            d = Decimal(str(v))
            if not d.is_finite() or (kind == 'integer' and d != d.to_integral()): raise ValueError()
            return str(d)
        if kind in ('date', 'time', 'timestamptz'):
            if kind == 'time' and isinstance(v, str):
                if not re.fullmatch(r'[0-2][0-9]:[0-5][0-9](?::[0-5][0-9](?:\.[0-9]{1,6})?)?', v): raise ValueError()
                return datetime.strptime(v, '%H:%M').time().isoformat() if len(v) == 5 else time.fromisoformat(v).isoformat()
            if type(v) not in (int, float): raise ValueError()
            d = Decimal(str(v))
            if not d.is_finite(): raise ValueError()
            dt = datetime(1899, 12, 30) + timedelta(microseconds=int(d * 86_400_000_000))
            if kind == 'date':
                if dt.time() != datetime.min.time(): raise ValueError()
                return dt.date().isoformat()
            if kind == 'time':
                if not 0 <= d < 1: raise ValueError()
                return dt.time().isoformat()
            return dt.replace(tzinfo=ZoneInfo('Asia/Kolkata')).isoformat()
        if kind == 'uuid': return str(uuid.UUID(v))
        if kind == 'text':
            if type(v) is bool: raise ValueError()
            if isinstance(v, (int, float)):
                d = Decimal(str(v))
                if not d.is_finite(): raise ValueError()
                return format(d, 'f').rstrip('0').rstrip('.') if '.' in format(d, 'f') else format(d, 'f')
            if not isinstance(v, str) or '\x00' in v: raise ValueError()
            return v  # preserve whitespace and identity, never strip or normalize.
    except (ValueError, TypeError, InvalidOperation, OverflowError):
        raise StopLoad('TYPE_INVALID') from None
    raise StopLoad('TYPE_INVALID')

def warnings_for(tab, row):
    # Approved snapshot-bound exceptions, not newly inferred business rules.
    result = []
    for code, issue in AUDIT['approved_warning_rows'].items():
        if issue['tab'] == tab and row in issue['rows']: result.append(code)
    return result

def transform(tab, row, cells, headers):
    if tab not in TABLES or headers != TABS[tab]['source_headers']: raise StopLoad('HEADER_CHANGED')
    if type(row) is not int or not 3 <= row <= TABS[tab]['last_data_row']: raise StopLoad('SCOPE_MISMATCH')
    if len(cells) > len(headers): raise StopLoad('ROW_INVALID')
    cells = cells + [{}] * (len(headers) - len(cells))
    fields = {f['name']: f for f in TABLES[tab]['fields']}
    record = {}
    for header, cell in zip(headers, cells):
        name = header.split(' (')[0]
        if name not in fields: raise StopLoad('HEADER_CHANGED')
        record[name] = parse_cell(cell, fields[name])
    for name, field in fields.items():
        if name not in record:
            if not field['nullable']: raise StopLoad('REQUIRED_VALUE')
            record[name] = None  # approved diagram-only nullable field.
    return {'tab': tab, 'sheet': TABS[tab]['sheet_id'], 'row': row,
            'raw': [c.get('userEnteredValue', {}) for c in cells],
            'formatted': [c.get('formattedValue') for c in cells],
            'record': record, 'warnings': warnings_for(tab, row)}

@dataclass(frozen=True)
class Approval:
    project: str
    source: str
    run_id: str
    snapshot_hash: str
    ranges: tuple  # (tab, first, last), exact full snapshot ranges
    writes_authorized: bool = False

    def validate(self, rows):
        if not self.writes_authorized: raise StopLoad('NOT_APPROVED')
        if self.project != PROJECT or self.source != SOURCE: raise StopLoad('SCOPE_MISMATCH')
        try: uuid.UUID(self.run_id)
        except ValueError: raise StopLoad('SCOPE_MISMATCH') from None
        expected = {(t, r) for t, first, last in self.ranges for r in range(first, last + 1)}
        if any(t not in TABLES or first < 3 or last > TABS[t]['last_data_row'] or first > last
               for t, first, last in self.ranges): raise StopLoad('SCOPE_MISMATCH')
        for r in rows:
            tab = r.get('tab')
            if tab not in TABLES: raise StopLoad('SCOPE_MISMATCH')
            if set(r) != {'tab','sheet','row','raw','formatted','record','warnings'}: raise StopLoad('ROW_INVALID')
            if len(r['raw']) != len(TABS[tab]['source_headers']) or len(r['formatted']) != len(r['raw']): raise StopLoad('ROW_INVALID')
            checked = transform(tab, r['row'], [{'userEnteredValue':v,'formattedValue':f} for v,f in zip(r['raw'],r['formatted'])], TABS[tab]['source_headers'])
            if canonical(checked) != canonical(r): raise StopLoad('ROW_INVALID')
        actual = [(r['tab'], r['row']) for r in rows]
        if len(actual) != len(set(actual)) or set(actual) != expected: raise StopLoad('SCOPE_MISMATCH')
        if sha(rows) != self.snapshot_hash: raise StopLoad('SOURCE_CHANGED')
        # A production snapshot includes both sides of the bootstrap audit cycle.
        if any(r['tab'] in ('24.Reference List', '23.Staff') for r in rows):
            for tab in ('24.Reference List', '23.Staff'):
                if {r['row'] for r in rows if r['tab'] == tab} != set(range(3, TABS[tab]['last_data_row'] + 1)):
                    raise StopLoad('SNAPSHOT_INCOMPLETE')

class Worker:
    """Fixed destination, inherited proxy/CA, no redirects, no automatic retries."""
    def __init__(self, project):
        if project != PROJECT or os.environ.get('SUPABASE_PROJECT_REF') != PROJECT:
            raise StopLoad('SCOPE_MISMATCH')
        self.token = os.environ.get('SUPABASE_ACCESS_TOKEN')
        if not self.token: raise StopLoad('PREFLIGHT_FAILED')
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *args): return None
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, suffix, payload=None):
        if suffix not in ('', '/postgrest', '/database/query'): raise StopLoad('SCOPE_MISMATCH')
        data = None if payload is None else canonical(payload).encode()
        if data is not None and len(data) > MAX_BYTES: raise StopLoad('PAYLOAD_TOO_LARGE')
        req = urllib.request.Request('https://api.supabase.com/v1/projects/' + PROJECT + suffix,
            data=data, headers={'Authorization': 'Bearer ' + self.token, 'Content-Type': 'application/json'})
        try:
            with self.opener.open(req, timeout=90) as response: return json.load(response)
        except Exception: raise StopLoad('WRITE_FAILED_OR_UNCERTAIN') from None

    def query(self, sql): return self.request('/database/query', {'query': sql})

    def preflight(self):
        p = self.request(''); c = self.request('/postgrest')
        if p.get('id') != PROJECT or p.get('name') != 'Veruschka-IDS-SampleProject' or p.get('status') != 'ACTIVE_HEALTHY':
            raise StopLoad('PREFLIGHT_FAILED')
        if {'ids', 'ids_import'} & {x.strip() for x in c.get('db_schema', '').split(',')}:
            raise StopLoad('PREFLIGHT_FAILED')
        if not c.get('db_schema'): raise StopLoad('PREFLIGHT_FAILED')
        check = self.query("""SELECT (
          (SELECT count(*)=28 AND bool_and(c.relrowsecurity) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('ids','ids_import') AND c.relkind='r')
          AND NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname IN ('ids','ids_import'))
          AND (SELECT count(*)=2 FROM supabase_migrations.schema_migrations WHERE version IN ('20261113125204','20261113125216'))
          AND NOT EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(coalesce(c.relacl,acldefault(CASE WHEN c.relkind='S' THEN 'S'::\"char\" ELSE 'r'::\"char\" END,c.relowner))) a WHERE n.nspname IN ('ids','ids_import') AND c.relkind IN ('r','p','v','m','S','f') AND (a.grantee=0 OR a.grantee IN(SELECT oid FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role'))))
          AND NOT EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a WHERE n.nspname IN ('ids','ids_import') AND (a.grantee=0 OR a.grantee IN(SELECT oid FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role'))))
        ) AS safe;""")
        if check != [{'safe': True}]: raise StopLoad('PREFLIGHT_FAILED')

def transaction(body, receipt):
    return ("BEGIN ISOLATION LEVEL READ COMMITTED;\nSET LOCAL standard_conforming_strings=on;\n"
            "SET LOCAL lock_timeout='5s';\nSET LOCAL search_path=pg_catalog;\nSET LOCAL statement_timeout='60s';\n"
            "SELECT pg_advisory_xact_lock(718134002);\nSET CONSTRAINTS ALL DEFERRED;\n" +
            block(body) + '\nSET CONSTRAINTS ALL IMMEDIATE;\nCOMMIT;\nSELECT ' +
            json_sql(receipt) + ' AS receipt;')

def chunks_for(rows):
    chunks = []
    for n in ORDER:
        tab = next(t for t in TABLES if t.startswith(str(n) + '.'))
        selected = sorted((r for r in rows if r['tab'] == tab), key=lambda r: r['row'])
        chunk = []
        for row in selected:
            if chunk and (len(chunk) == MAX_ROWS or row['row'] != chunk[-1]['row'] + 1):
                chunks.append(chunk); chunk = []
            chunk.append(row)
        if chunk: chunks.append(chunk)
    return chunks

class Journal:
    """Durable run state on an operator-provisioned persistent filesystem.

    No automatic initialization: a missing/untrusted journal always requires the
    explicit read-only Loader.reconcile operation, even for first execution.
    All processes for a run must share this path; lock survives atomic replaces.
    """
    def __init__(self, path):
        self.path = Path(path).resolve()
        if not Path(path).is_absolute() or self.path.is_relative_to(ROOT):
            raise StopLoad('SCOPE_MISMATCH')
        try: self.run_id = str(uuid.UUID(self.path.stem))
        except ValueError: raise StopLoad('SCOPE_MISMATCH') from None
        if self.path.name != self.run_id+'.json': raise StopLoad('SCOPE_MISMATCH')
        self.marker = self.path.with_suffix('.started')
        self.lock_path = self.path.with_suffix('.lock')
        self._fd = None

    @contextmanager
    def exclusive(self):
        if self._fd is not None: raise StopLoad('RUN_LOCKED')
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        fd = os.open(self.lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        try:
            try: fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError: raise StopLoad('RUN_LOCKED') from None
            self._fd = fd
            yield
        finally:
            if self._fd == fd: self._fd = None
            os.close(fd)

    def _read(self, path):
        try:
            with path.open() as f: return json.load(f)
        except Exception: raise StopLoad('RECONCILIATION_REQUIRED') from None

    def read(self):
        if self._fd is None: raise StopLoad('RUN_LOCKED')
        state = self._read(self.path); marker = self._read(self.marker)
        expected = {k:state.get(k) for k in ('run','snapshot','generation')}
        if marker != expected or state.get('state') not in ('ready','in_flight'):
            raise StopLoad('RECONCILIATION_REQUIRED')
        return state

    def _atomic(self, path, value):
        if self._fd is None: raise StopLoad('RUN_LOCKED')
        fd, temp = tempfile.mkstemp(dir=path.parent)
        try:
            with os.fdopen(fd, 'w') as f:
                f.write(canonical(value)); f.flush(); os.fsync(f.fileno())
            os.replace(temp, path)
            dirfd = os.open(path.parent, os.O_RDONLY)
            try: os.fsync(dirfd)
            finally: os.close(dirfd)
        finally:
            if os.path.exists(temp): os.unlink(temp)

    def reconciled(self, approval, mode):
        generation = str(uuid.uuid4())
        base = {'run':approval.run_id,'snapshot':approval.snapshot_hash,'generation':generation}
        # A crash between the two fsync'd replaces leaves mismatched state: stop.
        self._atomic(self.marker, base)
        self._atomic(self.path, dict(base,state='ready',attempt=None,mode=mode))

    def begin(self, approval, attempt, receipt):
        state = self.read()
        if state.get('run') != approval.run_id or state.get('snapshot') != approval.snapshot_hash or state['state'] != 'ready':
            raise StopLoad('RECONCILIATION_REQUIRED')
        self._atomic(self.path, dict(state,state='in_flight',attempt=attempt,receipt=receipt))

    def complete(self, attempt):
        state = self.read()
        if state['state'] != 'in_flight' or state.get('attempt') != attempt:
            raise StopLoad('ATTEMPT_CONFLICT')
        state.pop('receipt', None)
        self._atomic(self.path, dict(state,state='ready'))

class Loader:
    def __init__(self, approval, worker, failure_sink, journal):
        self.approval = approval; self.worker = worker; self.failure_sink = failure_sink
        self.stopped = False
        self.journal = journal

    def _send(self, sql, receipt):
        if len(canonical({'query': sql}).encode()) > MAX_BYTES: raise StopLoad('PAYLOAD_TOO_LARGE')
        attempt = str(uuid.uuid4())
        self.journal.begin(self.approval, attempt, receipt)
        response = self.worker.query(sql)
        if response != [{'receipt': receipt}]: raise StopLoad('RECEIPT_INVALID')
        self.journal.complete(attempt)

    def _run_guard(self, create=False):
        a = self.approval
        scope = {'ranges': a.ranges, 'snapshot_hash': a.snapshot_hash, 'loader_version': 1}
        scope_sql = json_sql(scope)
        rid = literal(a.run_id) + '::uuid'
        sql = ''
        if create:
            sql += (f"INSERT INTO ids_import.import_run(import_run_id,project_ref,source_file_id,approved_scope,source_timezone,source_manifest,status) VALUES ({rid},{literal(PROJECT)},{literal(SOURCE)},{scope_sql},'Asia/Kolkata',{json_sql({'snapshot_hash':a.snapshot_hash})},'running') ON CONFLICT(import_run_id) DO NOTHING;\n")
        sql += (f"IF NOT EXISTS(SELECT 1 FROM ids_import.import_run WHERE import_run_id={rid} AND project_ref={literal(PROJECT)} AND source_file_id={literal(SOURCE)} AND approved_scope={scope_sql} AND source_timezone='Asia/Kolkata' AND source_manifest={json_sql({'snapshot_hash':a.snapshot_hash})} AND status IN ('running','completed')) THEN RAISE EXCEPTION 'RUN_CONFLICT'; END IF;\n")
        return sql

    def _chunk_sql(self, rows, read_only=False):
        a = self.approval; first = rows[0]; last = rows[-1]
        table = TABLES[first['tab']]; target = 'ids.' + ident(table['name'])
        pk = next(f['name'] for f in table['fields'] if f['primary_key'])
        digest = sha(rows)
        cid = str(uuid.uuid5(uuid.UUID(a.run_id), f"{first['sheet']}:{first['row']}:{last['row']}"))
        rid = literal(a.run_id) + '::uuid'; chunk_id = literal(cid) + '::uuid'
        sheet, lo, hi = first['sheet'], first['row'], last['row']
        data = []
        for row in rows:
            sid = str(uuid.uuid5(uuid.UUID(a.run_id), f"{sheet}:{row['row']}"))
            data.append(dict(row, record=dict(row['record'], source_row_id=sid),
                             source_id=sid, raw_hash=sha(row['raw'])))
        columns = ','.join(ident(k) for k in data[0]['record'])
        fields = ' AND '.join(f't.{ident(k)} IS NOT DISTINCT FROM e.{ident(k)}' for k in data[0]['record'])
        predicate = f'import_chunk_id={chunk_id}'
        # A single JSON payload and set of loops keeps 174-row bootstrap bounded.
        # Field/table names come only from the checked-in model, never source data.
        sql = f"""DECLARE p jsonb := {json_sql(data)}; r jsonb;
BEGIN
IF EXISTS(SELECT 1 FROM ids_import.import_chunk WHERE {predicate}) THEN
  IF NOT EXISTS(SELECT 1 FROM ids_import.import_chunk WHERE {predicate} AND import_run_id={rid} AND source_sheet_id={sheet} AND first_row={lo} AND last_row={hi} AND payload_sha256={literal(digest)} AND status='committed') THEN RAISE EXCEPTION 'CHUNK_CONFLICT'; END IF;
ELSE
  IF NOT EXISTS(SELECT 1 FROM ids_import.import_run WHERE import_run_id={rid} AND status='running') THEN RAISE EXCEPTION 'RUN_COMPLETED'; END IF;
  INSERT INTO ids_import.import_chunk(import_chunk_id,import_run_id,source_sheet_id,first_row,last_row,payload_sha256,status) VALUES ({chunk_id},{rid},{sheet},{lo},{hi},{literal(digest)},'pending');
  FOR r IN SELECT value FROM jsonb_array_elements(p) LOOP
    INSERT INTO ids_import.source_row(source_row_id,import_run_id,import_chunk_id,source_file_id,source_sheet_id,source_tab,original_row,raw_values,raw_formatted_values,raw_sha256,disposition,target_table,target_record_key)
    VALUES ((r->>'source_id')::uuid,{rid},{chunk_id},{literal(SOURCE)},{sheet},{literal(first['tab'])},(r->>'row')::integer,r->'raw',r->'formatted',r->>'raw_hash','loaded',{literal('ids.'+table['name'])},r->'record'->>{literal(pk)});
    INSERT INTO {target}({columns}) SELECT {columns} FROM jsonb_populate_record(NULL::{target},r->'record');
    INSERT INTO ids_import.validation_issue(source_row_id,severity,reason_code,reason)
      SELECT (r->>'source_id')::uuid,'warning',code,code FROM jsonb_array_elements_text(r->'warnings') AS w(code);
  END LOOP;
  UPDATE ids_import.import_chunk SET status='committed',committed_at=now() WHERE {predicate};
END IF;
IF (SELECT count(*) FROM ids_import.source_row WHERE import_chunk_id={chunk_id})<>{len(rows)} THEN RAISE EXCEPTION 'ROW_COUNT_CONFLICT'; END IF;
IF (SELECT count(*) FROM {target} WHERE source_row_id IN (SELECT (value->>'source_id')::uuid FROM jsonb_array_elements(p)))<>{len(rows)} THEN RAISE EXCEPTION 'DOMAIN_COUNT_CONFLICT'; END IF;
FOR r IN SELECT value FROM jsonb_array_elements(p) LOOP
  IF NOT EXISTS(SELECT 1 FROM {target} t CROSS JOIN jsonb_populate_record(NULL::{target},r->'record') e WHERE {fields}) THEN RAISE EXCEPTION 'RECORD_CONFLICT'; END IF;
  IF NOT EXISTS(SELECT 1 FROM ids_import.source_row WHERE source_row_id=(r->>'source_id')::uuid AND import_run_id={rid} AND import_chunk_id={chunk_id} AND source_file_id={literal(SOURCE)} AND source_sheet_id={sheet} AND source_tab={literal(first['tab'])} AND original_row=(r->>'row')::integer AND raw_values=r->'raw' AND raw_formatted_values=r->'formatted' AND raw_sha256=r->>'raw_hash' AND disposition='loaded' AND target_table={literal('ids.'+table['name'])} AND target_record_key=r->'record'->>{literal(pk)}) THEN RAISE EXCEPTION 'LINEAGE_CONFLICT'; END IF;
  IF (SELECT coalesce(jsonb_agg(reason_code ORDER BY reason_code),'[]'::jsonb) FROM ids_import.validation_issue WHERE source_row_id=(r->>'source_id')::uuid)<>(SELECT coalesce(jsonb_agg(code ORDER BY code),'[]'::jsonb) FROM jsonb_array_elements_text(r->'warnings') AS w(code)) OR EXISTS(SELECT 1 FROM ids_import.validation_issue WHERE source_row_id=(r->>'source_id')::uuid AND (severity<>'warning' OR reason<>reason_code)) THEN RAISE EXCEPTION 'WARNING_CONFLICT'; END IF;
END LOOP;
END;
"""
        if read_only:
            branch = sql.index('\nELSE\n')
            end = sql.index('\nEND IF;\nIF (SELECT count(*)', branch)
            checks = sql[end + len('\nEND IF;'):sql.rfind('\nEND;')]
            sql = (sql[:branch] + checks + '\nELSE\n' +
                   f"IF EXISTS(SELECT 1 FROM ids_import.source_row WHERE import_run_id={rid} AND source_sheet_id={sheet} AND original_row BETWEEN {lo} AND {hi}) THEN RAISE EXCEPTION 'ORPHAN_LINEAGE'; END IF;\nEND IF;\nEND;\n")
        return sql, {'chunk': cid, 'sha256': digest, 'rows': len(rows)}

    def _compile(self, rows):
        chunks = chunks_for(rows)
        groups = []
        bootstrap = [c for c in chunks if c[0]['tab'] in ('24.Reference List', '23.Staff')]
        if bootstrap: groups.append(bootstrap)
        groups += [[c] for c in chunks if c[0]['tab'] not in ('24.Reference List','23.Staff')]
        # Compile and size-check every transaction before the first write.
        compiled = []
        pending = list(groups)
        while pending:
            group = pending.pop(0)
            body = self._run_guard(create=True); receipts = []
            for chunk in group:
                text, receipt = self._chunk_sql(chunk); body += text; receipts.append(receipt)
            receipt = {'run': self.approval.run_id, 'chunks': receipts}
            sql = transaction(body, receipt)
            if len(canonical({'query': sql}).encode()) > MAX_BYTES:
                if len(group) != 1 or len(group[0]) < 2: raise StopLoad('PAYLOAD_TOO_LARGE')
                chunk = group[0]
                if chunk[0]['tab'] in ('24.Reference List','23.Staff'): raise StopLoad('PAYLOAD_TOO_LARGE')
                midpoint = len(chunk) // 2
                pending[0:0] = [[chunk[:midpoint]], [chunk[midpoint:]]]
                continue
            compiled.append((sql, receipt, group))
        chunks = [chunk for _, _, group in compiled for chunk in group]
        return compiled, chunks

    def load(self, rows, repeated_rows):
        rows = private_snapshot(rows)
        repeated_rows = private_snapshot(repeated_rows)
        with self.journal.exclusive():
            return self._load_locked(rows, repeated_rows)

    def reconcile(self, rows, repeated_rows, *, authorized=False):
        """Explicit operator-authorized read-only reconciliation; never auto-retry.

        Required both to provision a first run and after loss/corruption/uncertainty.
        Operator must establish that previous requests have settled before invoking.
        This only restores local state; it never calls load or issues data writes.
        """
        if not authorized: raise StopLoad('NOT_APPROVED')
        rows = private_snapshot(rows); repeated_rows = private_snapshot(repeated_rows)
        with self.journal.exclusive():
            self.approval.validate(rows)
            if self.journal.run_id != self.approval.run_id: raise StopLoad('SCOPE_MISMATCH')
            if sha(rows) != sha(repeated_rows): raise StopLoad('SOURCE_CHANGED')
            self.worker.preflight()
            compiled, chunks = self._compile(rows)
            rid = literal(self.approval.run_id) + '::uuid'
            def read_check(body, receipt_expression):
                sql = ("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;\nSET LOCAL standard_conforming_strings=on;\nSET LOCAL search_path=pg_catalog;\nSET LOCAL lock_timeout='5s';\nSET LOCAL statement_timeout='60s';\nSELECT pg_advisory_xact_lock(718134002);\n" + block(body) +
                       f"\nSELECT {receipt_expression} AS receipt;\nCOMMIT;")
                if len(canonical({'query':sql}).encode()) > MAX_BYTES: raise StopLoad('PAYLOAD_TOO_LARGE')
                response = self.worker.query(sql)
                if not isinstance(response,list) or len(response)!=1: raise StopLoad('RECEIPT_INVALID')
                return response[0].get('receipt',{})
            ids = []
            # Same bounded groups as loading, but every request is READ ONLY.
            for _, _, group in compiled:
                body = f"IF EXISTS(SELECT 1 FROM ids_import.import_run WHERE import_run_id={rid}) THEN\n" + self._run_guard()
                receipts = []
                for chunk in group:
                    check, receipt = self._chunk_sql(chunk, read_only=True)
                    body += check; receipts.append(receipt)
                    ids.append(literal(receipt['chunk'])+'::uuid')
                body += '\nEND IF;'
                expected = {'run':self.approval.run_id,'checked':receipts}
                if read_check(body,json_sql(expected)) != expected: raise StopLoad('RECEIPT_INVALID')
            expected_ids = ','.join(ids) or 'NULL::uuid'
            body = f"IF EXISTS(SELECT 1 FROM ids_import.import_run WHERE import_run_id={rid}) THEN\n" + self._run_guard()
            body += f"IF EXISTS(SELECT 1 FROM ids_import.import_chunk WHERE import_run_id={rid} AND import_chunk_id NOT IN ({expected_ids})) OR (SELECT count(*) FROM ids_import.source_row WHERE import_run_id={rid})<>(SELECT coalesce(sum(last_row-first_row+1),0) FROM ids_import.import_chunk WHERE import_run_id={rid} AND status='committed') OR EXISTS(SELECT 1 FROM ids_import.import_run WHERE import_run_id={rid} AND status='completed' AND (SELECT count(*) FROM ids_import.import_chunk WHERE import_run_id={rid})<>{len(chunks)}) THEN RAISE EXCEPTION 'RECONCILIATION_FAILED'; END IF;\nEND IF;"
            base = {'run':self.approval.run_id,'snapshot':self.approval.snapshot_hash,'reconciled':True}
            receipt = read_check(body,f"{json_sql(base)} || jsonb_build_object('mode',CASE WHEN EXISTS(SELECT 1 FROM ids_import.import_run WHERE import_run_id={rid}) THEN 'resume' ELSE 'first' END)")
            mode = receipt.get('mode')
            if mode not in ('first','resume') or receipt != dict(base,mode=mode): raise StopLoad('RECEIPT_INVALID')
            self.journal.reconciled(self.approval,mode)
            return receipt

    def _load_locked(self, rows, repeated_rows):
        # A stopped instance cannot be reused after uncertainty, even if receipt was lost.
        if self.stopped: raise StopLoad('WRITE_FAILED_OR_UNCERTAIN')
        context = None
        try:
            self.approval.validate(rows)
            if self.journal.run_id != self.approval.run_id: raise StopLoad('SCOPE_MISMATCH')
            previous = self.journal.read()
            if previous.get('run') != self.approval.run_id or previous.get('snapshot') != self.approval.snapshot_hash or previous.get('state') != 'ready':
                raise StopLoad('RECONCILIATION_REQUIRED')
            if sha(rows) != sha(repeated_rows): raise StopLoad('SOURCE_CHANGED')
            self.worker.preflight()
            compiled, chunks = self._compile(rows)
            for sql, receipt, group in compiled:
                context = group
                self._send(sql, receipt)
            context = None
            rid = literal(self.approval.run_id) + '::uuid'
            body = self._run_guard()
            body += f"IF (SELECT count(*) FROM ids_import.source_row WHERE import_run_id={rid})<>{len(rows)} OR EXISTS(SELECT 1 FROM ids_import.source_row WHERE import_run_id={rid} AND disposition IS DISTINCT FROM 'loaded') OR (SELECT count(*) FROM ids_import.import_chunk WHERE import_run_id={rid} AND status='committed')<>{len(chunks)} OR EXISTS(SELECT 1 FROM ids_import.import_chunk WHERE import_run_id={rid} AND status<>'committed') THEN RAISE EXCEPTION 'RECONCILIATION_FAILED'; END IF;\n"
            body += f"UPDATE ids_import.import_run SET status='completed',finished_at=coalesce(finished_at,now()) WHERE import_run_id={rid};"
            receipt = {'run': self.approval.run_id, 'complete': True, 'rows': len(rows)}
            self._send(transaction(body, receipt), receipt)
            return receipt
        except Exception as exc:
            self.stopped = True
            code = exc.code if isinstance(exc, StopLoad) else 'WRITE_FAILED_OR_UNCERTAIN'
            # Sanitized source coordinates only. Never send SQL or database exception text.
            try:
                if context:
                    for chunk in context:
                        ack = self.failure_sink(SOURCE, f"{chunk[0]['tab']}!{chunk[0]['row']}:{chunk[-1]['row']}", code)
                        if ack is not True: raise StopLoad('FAILURE_LOG_FAILED')
                else:
                    if self.failure_sink(SOURCE, 'Scope notes', code) is not True: raise StopLoad('FAILURE_LOG_FAILED')
            except Exception: raise StopLoad('FAILURE_LOG_FAILED') from None
            raise StopLoad(code) from None


def main():
    parser = argparse.ArgumentParser(description='Offline dry-run only; never connects to the database.')
    parser.add_argument('snapshot', type=Path, help='private JSON: headers by tab and rows with tab/row/cells')
    args = parser.parse_args()
    try:
        snapshot = json.loads(args.snapshot.read_text())
        results = [transform(r['tab'], r['row'], r['cells'], snapshot['headers'][r['tab']]) for r in snapshot['rows']]
        print(canonical({'read': len(snapshot['rows']), 'transformed': len(results), 'warnings': sum(len(r['warnings']) for r in results), 'database_writes': 0}))
    except Exception as exc:
        print(canonical({'stopped': exc.code if isinstance(exc, StopLoad) else 'ROW_INVALID', 'database_writes': 0}))
        raise SystemExit(1) from None

if __name__ == '__main__': main()
