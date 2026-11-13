"""Real two-session races against the validator's disposable local database."""
import queue
import subprocess
import threading
import time
import uuid


class Session:
    def __init__(self, command, env):
        self.p = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, text=True, bufsize=1, env=env)
        self.output = queue.Queue()
        self.errors = []
        self.readers = [threading.Thread(target=self._stdout, daemon=True),
                        threading.Thread(target=self._stderr, daemon=True)]
        for t in self.readers:
            t.start()

    def _stdout(self):
        for line in self.p.stdout:
            self.output.put(line.rstrip())
        self.output.put(None)

    def _stderr(self):
        for line in self.p.stderr:
            self.errors.append(line)

    def write(self, sql):
        self.p.stdin.write(sql + '\n')
        self.p.stdin.flush()

    def execute(self, sql):
        marker = 'done_' + uuid.uuid4().hex
        self.write(sql + '\n\\echo ' + marker)
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            line = self.output.get(timeout=max(0.01, deadline - time.monotonic()))
            if line == marker:
                return
            if line is None:
                raise AssertionError('Session ended: ' + ''.join(self.errors))
        raise AssertionError('Session command timed out')

    def expected_error(self, codes):
        self.p.wait(timeout=10)
        for t in self.readers:
            t.join(timeout=1)
        message = ''.join(self.errors)
        if self.p.returncode == 0 or not any(code in message for code in codes):
            raise AssertionError('Expected one of ' + repr(codes) + ': ' + message)

    def close(self):
        if self.p.poll() is None:
            self.p.stdin.close()
            try:
                self.p.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.p.terminate()
                self.p.wait(timeout=3)
        for t in self.readers:
            t.join(timeout=1)


def run(command, env, query):
    sessions = []
    results = []

    def session():
        s = Session(command, env)
        sessions.append(s)
        return s

    def wait_for_lock(name):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if query("select exists(select 1 from pg_stat_activity where application_name='" +
                     name + "' and state='active' and wait_event_type='Lock');").strip() == 't':
                return
            time.sleep(0.02)
        raise AssertionError('Competing session did not block on a real lock: ' + name)

    try:
        for isolation in ('read committed', 'repeatable read'):
            suffix = isolation.replace(' ', '_')
            learner, contact, batch, enrolment = ['CONC-' + x + '-' + suffix for x in ('L','C','B','E')]
            query(f"insert into ids.learner_profile(learner_id) values ('{learner}'); "
                  f"insert into ids.family_contact(contact_id,learner_id) values ('{contact}','{learner}'); "
                  f"insert into ids.batch(batch_id,program_id) values ('{batch}','programme.ILS');")
            parent, child = session(), session()
            name = 'context_race_' + suffix
            # Establish the parent's snapshot before the child exists.
            parent.execute(f"set application_name='{name}'; begin isolation level {isolation}; select 1;")
            child.execute(f"begin; insert into ids.enrolment(enrolment_id,learner_id,batch_id,supporter_contact_id) "
                          f"values ('{enrolment}','{learner}','{batch}','{contact}');")
            parent.write(f"update ids.family_contact set learner_id='DUMMY-L2' where contact_id='{contact}'; commit;")
            wait_for_lock(name)
            child.execute('commit;')
            parent.expected_error(('23503','40001'))
            if query(f"select c.learner_id=e.learner_id from ids.enrolment e join ids.family_contact c "
                     f"on c.contact_id=e.supporter_contact_id where e.enrolment_id='{enrolment}';").strip() != 't':
                raise AssertionError('Cross-learner relationship survived concurrent parent change')
            results.append('composite FK race: ' + isolation)

        # A score transaction holds SHARE on the rubric until commit. The waiting
        # READ COMMITTED definition update must see the newly committed score.
        query("insert into ids.criterion_catalogue(criterion_id,assessment_type_id,rubric_version,criterion_number,criterion_name,maximum_score) "
              "values ('CONC-CR','assessment_type.FUNCTIONAL','DUMMY-RUBRIC',90,'Concurrency dummy criterion',5);")
        parent, child = session(), session()
        parent.execute("set application_name='rubric_race'; begin isolation level read committed; select 1;")
        child.execute("begin; insert into ids.criterion_score(criterion_score_id,assessment_event_id,criterion_id,score_value) "
                      "values ('CONC-CS','DUMMY-A1','CONC-CR',3);")
        parent.write("update ids.criterion_catalogue set criterion_description='Changed' where criterion_id='CONC-CR'; commit;")
        wait_for_lock('rubric_race')
        child.execute('commit;')
        parent.expected_error(('23514',))
        results.append('used rubric concurrent definition update: read committed')

        for isolation in ('repeatable read','serializable'):
            s = session()
            s.write(f"begin isolation level {isolation}; update ids.criterion_catalogue "
                    "set criterion_description='Changed' where criterion_id='DUMMY-CR2'; commit;")
            s.expected_error(('0A000',))
            results.append('definition-update isolation rejected: ' + isolation)
        return results
    finally:
        for s in sessions:
            s.close()
