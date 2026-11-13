"""Offline tests only: fake worker, synthetic cells, PostgreSQL parser; no database."""
import copy
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import load_ids as L

RUN = '11111111-1111-4111-8111-111111111111'

def fixture(tab='5.Monthly Target', row=3):
    values = {}
    for f in L.TABLES[tab]['fields']:
        if f['nullable']: continue
        if f['type'] in ('date','timestamptz'): value={'numberValue':44711}
        elif f['type'] in ('integer','numeric'): value={'numberValue':1}
        elif f['type']=='boolean': value={'boolValue':True}
        else: value={'stringValue':'fixture_'+f['name']+str(row)}
        values[f['name']]={'userEnteredValue':value}
    cells = [values.get(h.split(' (')[0], {}) for h in L.TABS[tab]['source_headers']]
    return L.transform(tab,row,cells,L.TABS[tab]['source_headers'])

def approval(rows, authorized=True):
    ranges = tuple((c[0]['tab'],c[0]['row'],c[-1]['row']) for c in L.chunks_for(rows))
    return L.Approval(L.PROJECT,L.SOURCE,RUN,L.sha(rows),ranges,authorized)

class FakeWorker:
    def __init__(self, mode='ok'): self.sql=[];self.mode=mode;self.preflights=0
    def preflight(self): self.preflights+=1
    def query(self, sql):
        self.sql.append(sql)
        if self.mode=='timeout': raise TimeoutError('PRIVATE DATABASE DETAIL')
        if self.mode=='bad_receipt': return []
        # Last SELECT contains the exact safely quoted JSON receipt.
        last=sql.rsplit('\nSELECT ',1)[1]
        receipt=json.loads(last.split("'::jsonb AS receipt;",1)[0][1:].replace("''", "'"))
        return [{'receipt':receipt}]

class LoadTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.journal=L.Journal(Path(self.temp.name)/'work'/'journal.json')
        self.failures=[];self.worker=FakeWorker();self.rows=[fixture()]
    def loader(self, a=None, worker=None):
        return L.Loader(a or approval(self.rows),worker or self.worker,lambda *x:(self.failures.append(x) or True),self.journal)
    def test_default_approval_denies(self):
        with self.assertRaisesRegex(L.StopLoad,'NOT_APPROVED'):self.loader(approval(self.rows,False)).load(self.rows,self.rows)
        self.assertFalse(self.worker.sql)
    def test_project_denies(self):
        a=approval(self.rows);a=L.Approval('other',a.source,a.run_id,a.snapshot_hash,a.ranges,True)
        with self.assertRaises(L.StopLoad):self.loader(a).load(self.rows,self.rows)
        self.assertFalse(self.worker.sql)
    def test_source_denies(self):
        a=approval(self.rows);a=L.Approval(a.project,'backup',a.run_id,a.snapshot_hash,a.ranges,True)
        with self.assertRaises(L.StopLoad):self.loader(a).load(self.rows,self.rows)
    def test_changed_snapshot_denies(self):
        changed=copy.deepcopy(self.rows);changed[0]['record']['target_id']='changed'
        with self.assertRaises(L.StopLoad):self.loader().load(self.rows,changed)
        self.assertFalse(self.worker.sql)
    def test_forged_transform_denies(self):
        rows=copy.deepcopy(self.rows);rows[0]['record']['target_id']='changed'
        with self.assertRaises(L.StopLoad):approval(rows).validate(rows)
    def test_duplicate_rows_denies(self):
        with self.assertRaises(L.StopLoad):approval(self.rows*2).validate(self.rows*2)
    def test_outside_range_denies(self):
        a=approval(self.rows);a=L.Approval(a.project,a.source,a.run_id,a.snapshot_hash,(('5.Monthly Target',4,4),),True)
        with self.assertRaises(L.StopLoad):a.validate(self.rows)
    def test_incomplete_bootstrap_denies(self):
        rows=[fixture('23.Staff')]
        with self.assertRaisesRegex(L.StopLoad,'SNAPSHOT_INCOMPLETE'):approval(rows).validate(rows)
    def test_atomic_and_verified(self):
        receipt=self.loader().load(self.rows,self.rows)
        self.assertTrue(receipt['complete']);self.assertEqual(len(self.worker.sql),2)
        sql=self.worker.sql[0]
        for fragment in ['BEGIN ISOLATION LEVEL READ COMMITTED','pg_advisory_xact_lock','SET CONSTRAINTS ALL DEFERRED','INSERT INTO ids_import.source_row','INSERT INTO ids."monthly_target"','UPDATE ids_import.import_chunk',"status='committed'",'RECORD_CONFLICT','LINEAGE_CONFLICT','WARNING_CONFLICT','SET CONSTRAINTS ALL IMMEDIATE','COMMIT;']:
            self.assertIn(fragment,sql)
        self.assertNotIn('UPDATE ids."monthly_target"',sql)
        self.assertNotIn('ON CONFLICT DO UPDATE',sql)
        self.assertEqual(self.journal.read()['state'],'ready')
        self.assertEqual(os.stat(self.journal.path).st_mode&0o777,0o600)
    def test_replay_sql_same_ids_and_hash(self):
        a=self.loader()._chunk_sql(self.rows);b=self.loader()._chunk_sql(copy.deepcopy(self.rows))
        self.assertEqual(a,b)
        self.assertIn('CHUNK_CONFLICT',a[0]);self.assertIn('ROW_COUNT_CONFLICT',a[0])
    def test_failed_write_stops_and_survives_restart(self):
        worker=FakeWorker('timeout');loader=self.loader(worker=worker)
        with self.assertRaisesRegex(L.StopLoad,'WRITE_FAILED_OR_UNCERTAIN'):loader.load(self.rows,self.rows)
        self.assertEqual(len(worker.sql),1)
        self.assertEqual(self.journal.read()['state'],'in_flight')
        with self.assertRaises(L.StopLoad):self.loader().load(self.rows,self.rows)
        self.assertFalse(self.worker.sql)
        self.assertNotIn('PRIVATE',json.dumps(self.failures))
    def test_bad_receipt_stops(self):
        worker=FakeWorker('bad_receipt')
        with self.assertRaisesRegex(L.StopLoad,'RECEIPT_INVALID'):self.loader(worker=worker).load(self.rows,self.rows)
        self.assertEqual(len(worker.sql),1)
    def test_failure_sink_failure_stops(self):
        def sink(*args):raise OSError('private')
        loader=L.Loader(approval(self.rows),FakeWorker('timeout'),sink,self.journal)
        with self.assertRaisesRegex(L.StopLoad,'FAILURE_LOG_FAILED'):loader.load(self.rows,self.rows)
    def test_chunk_limit_and_gaps(self):
        rows=[fixture(row=n) for n in range(3,105)]+[fixture(row=110)]
        self.assertEqual([len(c)for c in L.chunks_for(rows)],[100,2,1])
    def test_blanks_stay_null(self):self.assertIsNone(L.parse_cell({}, {'type':'numeric','nullable':True}))
    def test_required_blank_denies(self):
        with self.assertRaises(L.StopLoad):L.parse_cell({}, {'type':'text','nullable':False})
    def test_stale_format_boolean(self):
        cell={'userEnteredValue':{'boolValue':True},'userEnteredFormat':{'numberFormat':{'type':'DATE'}}}
        self.assertIs(L.parse_cell(cell,{'type':'boolean','nullable':True}),True)
    def test_numeric_text(self):
        self.assertEqual(L.parse_cell({'userEnteredValue':{'numberValue':10}}, {'type':'text','nullable':True}),'10')
    def test_source_whitespace_preserved(self):
        self.assertEqual(L.parse_cell({'userEnteredValue':{'stringValue':'  x  '}}, {'type':'text','nullable':True}),'  x  ')
    def test_formula_denies(self):
        with self.assertRaisesRegex(L.StopLoad,'FORMULA_FOUND'):L.parse_cell({'userEnteredValue':{'formulaValue':'=1'}},{'type':'integer','nullable':True})
    def test_strict_time_text(self):
        self.assertEqual(L.parse_cell({'userEnteredValue':{'stringValue':'09:30'}},{'type':'time','nullable':True}),'09:30:00')
        for text in ['25:00','tomorrow','9:30']:
            with self.assertRaises(L.StopLoad):L.parse_cell({'userEnteredValue':{'stringValue':text}},{'type':'time','nullable':True})
    def test_timezone(self):
        self.assertEqual(L.parse_cell({'userEnteredValue':{'numberValue':44711}},{'type':'timestamptz','nullable':True}),'2022-05-30T00:00:00+05:30')
    def test_nonfinite_denies(self):
        for v in ['NaN','Infinity',True]:
            with self.assertRaises(L.StopLoad):L.parse_cell({'userEnteredValue':{'stringValue':v}},{'type':'numeric','nullable':True})
    def test_header_change_denies(self):
        with self.assertRaisesRegex(L.StopLoad,'HEADER_CHANGED'):L.transform('5.Monthly Target',3,[],['changed'])
    def test_sql_literal_and_dollar_delimiter(self):
        self.assertEqual(L.literal("x'); SELECT 'y"),"'x''); SELECT ''y'")
        sql=L.block("PERFORM '$ids_loader$';")
        self.assertNotEqual(sql.splitlines()[0],'DO $ids_loader$')
        with self.assertRaises(L.StopLoad):L.literal('\x00')
    def test_worker_scope_guard_without_network(self):
        with patch.dict(os.environ,{'SUPABASE_PROJECT_REF':'other'}):
            with self.assertRaises(L.StopLoad):L.Worker(L.PROJECT)
    def test_worker_no_redirect(self):
        with patch.dict(os.environ,{'SUPABASE_PROJECT_REF':L.PROJECT,'SUPABASE_ACCESS_TOKEN':'synthetic'}):
            w=L.Worker(L.PROJECT)
            handlers=[h for h in w.opener.handlers if hasattr(h,'redirect_request')]
            self.assertEqual(len(handlers),1);self.assertIsNone(handlers[0].redirect_request(None,None,None,None,None,None))
    def test_payload_cap_before_write(self):
        with patch.object(L,'MAX_BYTES',100):
            with self.assertRaisesRegex(L.StopLoad,'PAYLOAD_TOO_LARGE'):self.loader().load(self.rows,self.rows)
        self.assertFalse(self.worker.sql)
    def test_oversized_chunks_split_before_any_write(self):
        rows=[fixture(row=n) for n in range(3,103)]
        worker=FakeWorker()
        with patch.object(L,'MAX_BYTES',25000):
            L.Loader(approval(rows),worker,lambda *x:True,self.journal).load(rows,rows)
        self.assertGreater(len(worker.sql),2)
        self.assertTrue(all(len(L.canonical({'query':sql}).encode())<=25000 for sql in worker.sql))
    def test_preflight_rejects_exposure_and_bad_catalog(self):
        for schemas,catalog in [('public,ids',[{'safe':True}]),('public',[{'safe':False}])]:
            with patch.dict(os.environ,{'SUPABASE_PROJECT_REF':L.PROJECT,'SUPABASE_ACCESS_TOKEN':'synthetic'}):
                worker=L.Worker(L.PROJECT)
            project={'id':L.PROJECT,'name':'Veruschka-IDS-SampleProject','status':'ACTIVE_HEALTHY'}
            with patch.object(worker,'request',side_effect=[project,{'db_schema':schemas},catalog]):
                with self.assertRaisesRegex(L.StopLoad,'PREFLIGHT_FAILED'):worker.preflight()
    def test_full_bootstrap_order(self):
        rows=[]
        for tab in ('24.Reference List','23.Staff'):
            rows.extend(fixture(tab,row=n) for n in range(3,L.TABS[tab]['last_data_row']+1))
        worker=FakeWorker();L.Loader(approval(rows),worker,lambda *x:None,self.journal).load(rows,rows)
        self.assertEqual(len(worker.sql),2)
        sql=worker.sql[0]
        self.assertLess(sql.rindex('INSERT INTO ids."reference_list"'),sql.index('INSERT INTO ids."staff"'))
        self.assertEqual(sql.count('COMMIT;'),1)
    def test_failure_sink_declined_stops(self):
        loader=L.Loader(approval(self.rows),FakeWorker('timeout'),lambda *x:False,self.journal)
        with self.assertRaisesRegex(L.StopLoad,'FAILURE_LOG_FAILED'):loader.load(self.rows,self.rows)
    def test_warning_manifest_counts(self):
        self.assertEqual(len(L.AUDIT['approved_warning_rows']['weekly_check_first_held_rule']['rows']),61)
        self.assertIn('mou_signed_missing_date',L.warnings_for('4.Partner Organisation',5))
    def test_postgres_parses_all_table_statements(self):
        try:from pglast import parse_sql,parse_plpgsql
        except ImportError:self.skipTest('install pinned SQL parser')
        for tab in L.TABLES:
            with patch.dict(L.TABS[tab],{'last_data_row':max(3,L.TABS[tab]['last_data_row'])}):
                row=fixture(tab)
            loader=self.loader()
            body,_=loader._chunk_sql([row])
            sql=L.transaction(loader._run_guard(create=True)+body,{'test':True})
            parse_sql(sql)
            parse_plpgsql(sql[sql.index('DO '):sql.index('\nSET CONSTRAINTS ALL IMMEDIATE;')])
    def test_postgres_parses_generated_sql(self):
        try:from pglast import parse_sql, parse_plpgsql
        except ImportError:self.skipTest('install pinned requirements-loader-test.txt for SQL parser checks')
        self.loader().load(self.rows,self.rows)
        for sql in self.worker.sql:
            parse_sql(sql)
            # parse_plpgsql accepts DO statements and checks PL/pgSQL structure.
            parse_plpgsql(sql[sql.index('DO '):sql.index('\nSET CONSTRAINTS ALL IMMEDIATE;')])

if __name__=='__main__':unittest.main()
