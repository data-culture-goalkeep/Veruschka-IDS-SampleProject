"""Real PostgreSQL tests; only a disposable network-isolated local Docker DB."""
import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import unittest
import uuid
from test_load_ids import L, fixture, approval, RUN

ROOT = Path(__file__).resolve().parents[1]
IMAGE = 'postgres:17.11-bookworm@sha256:665dc7b37ac52a17e298511414c21d23ffa4e6a6ef6225b3e5d59c7afb35e994'
DOCKER = ['docker','--host=unix:///var/run/docker.sock']
ENV = {k:v for k,v in os.environ.items() if not k.startswith(('SUPABASE_','PG','DOCKER_HOST','DOCKER_CONTEXT','DOCKER_TLS','DOCKER_CERT_PATH'))}

def run(args, data=None, check=True):
    p = subprocess.run(args,input=data,text=True,capture_output=True,env=ENV,timeout=90)
    if check and p.returncode: raise RuntimeError('LOCAL_POSTGRES_COMMAND_FAILED: '+p.stderr[:300])
    return p

class LocalWorker(L.Worker):
    def __init__(self, test):
        self.test=test;self.writes=0;self.queries=[];self.lose_response=False
        self.started=None;self.release=None
    def request(self, suffix, payload=None):
        if suffix=='':return {'id':L.PROJECT,'name':'Veruschka-IDS-SampleProject','status':'ACTIVE_HEALTHY'}
        if suffix=='/postgrest':return {'db_schema':'public,graphql_public'}
        raise AssertionError('No remote or HTTP route is available in integration tests')
    def query(self, sql):
        readonly='READ ONLY' in sql or ' AS safe;' in sql
        if not readonly:
            self.writes+=1
            if self.started:self.started.set();self.release.wait(timeout=10)
        self.queries.append(sql)
        try:result=self.test.sql(sql)
        except RuntimeError:raise L.StopLoad('WRITE_FAILED_OR_UNCERTAIN') from None
        if not readonly and self.lose_response:
            self.lose_response=False
            raise TimeoutError('synthetic response loss after real COMMIT')
        if ' AS safe;' in sql:return [{'safe':result.strip()=='t'}]
        lines=[line for line in result.splitlines() if line.startswith('{')]
        return [{'receipt':json.loads(lines[-1])}] if lines else []

class PostgreSQLLoaderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.name='ids-loader-test-'+uuid.uuid4().hex[:10]
        run(DOCKER+['info','--format','{{.ServerVersion}}'])
        run(DOCKER+['run','--detach','--rm','--name',cls.name,'--network','none',
                    '-e','POSTGRES_HOST_AUTH_METHOD=trust','-e','POSTGRES_DB=ids_template',IMAGE])
        try:
            for _ in range(100):
                if run(DOCKER+['exec',cls.name,'pg_isready','-h','127.0.0.1','-U','postgres','-d','ids_template'],check=False).returncode==0:break
                time.sleep(.1)
            else:raise RuntimeError('Local PostgreSQL readiness failed')
            cls.command=DOCKER+['exec','-i',cls.name,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','postgres']
            def setup(sql):run(cls.command+['-d','ids_template'],sql)
            setup((ROOT/'tests/supabase_compat.sql').read_text())
            for migration in sorted((ROOT/'supabase/migrations').glob('*.sql')):setup(migration.read_text())
            setup("CREATE SCHEMA supabase_migrations; CREATE TABLE supabase_migrations.schema_migrations(version text PRIMARY KEY,name text);")
            for migration in sorted((ROOT/'supabase/migrations').glob('*.sql')):
                version,name=migration.stem.split('_',1)
                setup(f"INSERT INTO supabase_migrations.schema_migrations VALUES ('{version}','{name}');")
        except BaseException:
            run(DOCKER+['rm','-f',cls.name],check=False);raise
    @classmethod
    def tearDownClass(cls):run(DOCKER+['rm','-f',cls.name],check=False)
    def setUp(self):
        self.database='case_'+uuid.uuid4().hex
        run(DOCKER+['exec',self.name,'createdb','-U','postgres','-T','ids_template',self.database])
        self.addCleanup(lambda:run(DOCKER+['exec',self.name,'dropdb','-U','postgres',self.database],check=False))
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.journal=L.Journal(Path(self.temp.name)/'state'/(RUN+'.json'))
        self.worker=LocalWorker(self);self.failures=[]
    def sql(self, sql):return run(self.command+['-d',self.database],sql).stdout
    def scalar(self, sql):return int(self.sql(sql).strip())
    def rows(self):return [fixture('4.Partner Organisation',row=i) for i in (3,4)]
    def loader(self, rows, worker=None):return L.Loader(approval(rows),worker or self.worker,lambda *x:(self.failures.append(x) or True),self.journal)
    def prepare(self, rows):
        loader=self.loader(rows)
        receipt=loader.reconcile(rows,copy.deepcopy(rows),authorized=True)
        self.assertEqual(receipt['mode'],'first');self.assertEqual(self.worker.writes,0)
        return loader
    def state(self):
        with self.journal.exclusive():return self.journal.read()
    def counts(self):
        return [self.scalar('SELECT count(*) FROM '+t) for t in ('ids.partner_organisation','ids_import.source_row','ids_import.import_chunk')]
    def bootstrap(self, invalid=False):
        result=[]
        for tab in ('24.Reference List','23.Staff'):
            for n in range(3,L.TABS[tab]['last_data_row']+1):
                values={'created_by':'SYNTH_STAFF_3','updated_by':'SYNTH_STAFF_3'}
                if tab=='24.Reference List':
                    values.update(reference_value_id=f'staff_type.SYNTH_{n}',list_name='staff_type',display_label=f'Synthetic option {n}')
                    if invalid and n==3:values['updated_by']='SYNTH_MISSING'
                else:values.update(staff_id=f'SYNTH_STAFF_{n}',staff_type_id='staff_type.SYNTH_3')
                cells=[{'userEnteredValue':{'stringValue':values[h.split(' (')[0]]}} if h.split(' (')[0] in values else {} for h in L.TABS[tab]['source_headers']]
                result.append(L.transform(tab,n,cells,L.TABS[tab]['source_headers']))
        return result
    def test_goal_review_new_boundaries_preserve_lower_limits(self):
        sections={'SMART_GOALS':1,'FUNCTIONAL_LEARNING':0,'HOSPITALITY':0}
        self.sql("INSERT INTO ids.reference_list(reference_value_id,list_name,display_label) VALUES ('programme.ILS','programme','Synthetic ILS'),('goal_section.SMART_GOALS','goal_section','Synthetic SMART'),('goal_section.FUNCTIONAL_LEARNING','goal_section','Synthetic Functional'),('goal_section.HOSPITALITY','goal_section','Synthetic Hospitality'); INSERT INTO ids.learner_profile(learner_id) VALUES ('learner'); INSERT INTO ids.batch(batch_id,program_id) VALUES ('batch','programme.ILS'); INSERT INTO ids.enrolment(enrolment_id,learner_id,batch_id) VALUES ('enrolment','learner','batch');")
        for n,(section,minimum) in enumerate(sections.items(),1):
            self.sql(f"INSERT INTO ids.goal(goal_id,enrolment_id,goal_number,goal_section_id) VALUES ('goal{n}','enrolment',{n},'goal_section.{section}'); INSERT INTO ids.goal_review(goal_review_id,goal_id,milestone_week) VALUES ('review{n}','goal{n}',24);")
            for column in ('faculty_rating_score','family_rating_score'):
                for score in (minimum,5):
                    self.sql(f"UPDATE ids.goal_review SET {column}={score} WHERE goal_review_id='review{n}';")
                for score in (minimum-1,5.01,6):
                    with self.assertRaises(RuntimeError):
                        self.sql(f"UPDATE ids.goal_review SET {column}={score} WHERE goal_review_id='review{n}';")
                self.assertEqual(self.sql(f"SELECT {column} FROM ids.goal_review WHERE goal_review_id='review{n}';").strip(),'5')
                self.sql(f"UPDATE ids.goal_review SET {column}=NULL WHERE goal_review_id='review{n}';")

    def test_month_conversion_database_and_raw_lineage(self):
        self.sql("INSERT INTO ids.staff(staff_id) VALUES ('fixture_staff_id3');")
        row=fixture();headers=L.TABS[row['tab']]['source_headers']
        cells=[{'userEnteredValue':v} for v in row['raw']]
        index=next(i for i,h in enumerate(headers) if h.split(' (')[0]=='month')
        cells[index]={'userEnteredValue':{'stringValue':'2026-11'}}
        rows=[L.transform(row['tab'],3,cells,headers)]
        self.prepare(rows).load(rows,copy.deepcopy(rows))
        self.assertEqual(self.sql('SELECT month FROM ids.monthly_target;').strip(),'2026-11-01')
        self.assertEqual(self.sql(f"SELECT raw_values->{index}->>'stringValue' FROM ids_import.source_row;").strip(),'2026-11')

    def test_mid_chunk_error_rolls_back_everything(self):
        rows=self.rows();rows[1]['raw'][0]=copy.deepcopy(rows[0]['raw'][0]);rows[1]['record']['partner_organisation_id']=rows[0]['record']['partner_organisation_id']
        loader=self.prepare(rows)
        with self.assertRaises(L.StopLoad):loader.load(rows,copy.deepcopy(rows))
        self.assertEqual(self.counts(),[0,0,0]);self.assertEqual(self.scalar('SELECT count(*) FROM ids_import.import_run'),0)
        self.assertEqual(self.worker.writes,1);self.assertEqual(self.state()['state'],'in_flight')
    def test_deferred_bootstrap_failure_rolls_back_all_185_rows(self):
        rows=self.bootstrap(invalid=True);loader=self.prepare(rows)
        with self.assertRaises(L.StopLoad):loader.load(rows,copy.deepcopy(rows))
        for t in ('ids.reference_list','ids.staff','ids_import.source_row','ids_import.import_chunk','ids_import.import_run'):
            self.assertEqual(self.scalar('SELECT count(*) FROM '+t),0)
        self.assertEqual(self.worker.writes,1)
    def test_bootstrap_preserves_audit_cycle(self):
        rows=self.bootstrap();loader=self.prepare(rows);loader.load(rows,copy.deepcopy(rows))
        self.assertEqual(self.scalar('SELECT count(*) FROM ids.reference_list'),165)
        self.assertEqual(self.scalar('SELECT count(*) FROM ids.staff'),20)
        self.assertEqual(self.scalar("SELECT count(*) FROM ids.reference_list WHERE created_by='SYNTH_STAFF_3' AND updated_by='SYNTH_STAFF_3'"),165)
    def test_identical_replay_adds_no_records(self):
        rows=self.rows();self.prepare(rows).load(rows,copy.deepcopy(rows));before=self.counts()
        self.loader(rows).load(rows,copy.deepcopy(rows));self.assertEqual(self.counts(),before)
        self.assertEqual(before,[2,2,1])
    def test_changed_replay_rejected_by_python_and_database(self):
        rows=self.rows();loader=self.prepare(rows);loader.load(rows,copy.deepcopy(rows))
        changed=copy.deepcopy(rows);changed[0]['raw'][1]={'stringValue':'Synthetic changed'};changed[0]['record']['organisation_name']='Synthetic changed'
        writes=self.worker.writes
        with self.assertRaises(L.StopLoad):self.loader(changed).load(changed,copy.deepcopy(changed))
        self.assertEqual(self.worker.writes,writes)
        body,_=loader._chunk_sql(changed)
        with self.assertRaises(L.StopLoad):self.worker.query(L.transaction(loader._run_guard()+body,{'test':'changed_chunk'}))
        self.assertEqual(self.counts(),[2,2,1]);self.assertEqual(self.scalar("SELECT count(*) FROM ids.partner_organisation WHERE organisation_name='Synthetic changed'"),0)
    def test_tampered_lineage_replay_and_reconciliation_rejected(self):
        rows=self.rows();self.prepare(rows).load(rows,copy.deepcopy(rows))
        self.sql("UPDATE ids_import.source_row SET raw_values='[]'::jsonb WHERE original_row=3;")
        with self.assertRaises(L.StopLoad):self.loader(rows).load(rows,copy.deepcopy(rows))
        with self.assertRaises(L.StopLoad):self.loader(rows).reconcile(rows,copy.deepcopy(rows),authorized=True)
        self.assertEqual(self.counts(),[2,2,1]);self.assertEqual(self.state()['state'],'in_flight')
    def test_two_concurrent_attempts_only_one_enters_database(self):
        rows=self.rows();self.prepare(rows)
        self.worker.started=threading.Event();self.worker.release=threading.Event();errors=[]
        def first():
            try:self.loader(rows).load(rows,copy.deepcopy(rows))
            except BaseException as exc:errors.append(type(exc).__name__)
        thread=threading.Thread(target=first);thread.start()
        try:
            self.assertTrue(self.worker.started.wait(timeout=10))
            second=LocalWorker(self)
            other=L.Loader(approval(rows),second,lambda *x:True,L.Journal(self.journal.path))
            with self.assertRaisesRegex(L.StopLoad,'RUN_LOCKED'):other.load(rows,copy.deepcopy(rows))
            self.assertEqual(second.queries,[])
        finally:self.worker.release.set();thread.join(timeout=15)
        self.assertFalse(thread.is_alive());self.assertEqual(errors,[]);self.assertEqual(self.counts(),[2,2,1]);self.assertEqual(self.state()['state'],'ready')
    def test_commit_succeeded_response_lost_requires_readonly_reconciliation(self):
        rows=self.rows();loader=self.prepare(rows);self.worker.lose_response=True
        with self.assertRaises(L.StopLoad):loader.load(rows,copy.deepcopy(rows))
        self.assertEqual(self.counts(),[2,2,1]);self.assertEqual(self.state()['state'],'in_flight')
        self.journal.path.unlink() # Simulate journal loss; separate durable marker remains.
        writes=self.worker.writes
        with self.assertRaisesRegex(L.StopLoad,'RECONCILIATION_REQUIRED'):self.loader(rows).load(rows,copy.deepcopy(rows))
        self.assertEqual(self.worker.writes,writes)
        new=self.loader(rows);receipt=new.reconcile(rows,copy.deepcopy(rows),authorized=True)
        self.assertEqual(receipt['mode'],'resume');self.assertEqual(self.worker.writes,writes)
        new.load(rows,copy.deepcopy(rows));self.assertEqual(self.counts(),[2,2,1])
        self.assertEqual(self.scalar("SELECT count(*) FROM ids_import.import_run WHERE status='completed'"),1)

if __name__=='__main__':unittest.main()
