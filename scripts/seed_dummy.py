#!/usr/bin/env python3
"""Emit invented dummy records as SQL; this script never connects to a database."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def literal(value):
    if value is None:
        return 'null'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def insert(table, **values):
    return (f"insert into ids.{table} ({', '.join(values)}) values "
            f"({', '.join(literal(v) for v in values.values())});")


def sql():
    out = ['-- Invented local validation data. No source people/rows.', 'begin;']
    for option in json.loads((ROOT / 'config/reference-options.json').read_text()):
        out.append(insert('reference_list', **option))
    records = [
        ('staff', dict(staff_id='DUMMY-STAFF', full_name='Dummy Faculty', email='dummy@example.invalid',
                       staff_type_id='staff_type.INTERNAL_STAFF', is_active=True)),
        ('learner_profile', dict(learner_id='DUMMY-L1', first_name='Dummy One', registration_no='DUMMY-REG-1',
                                 date_of_birth='2000-01-01', gender='unspecified', is_active=True)),
        ('learner_profile', dict(learner_id='DUMMY-L2', first_name='Dummy Two', is_active=True)),
        ('family_contact', dict(contact_id='DUMMY-C1', learner_id='DUMMY-L1', contact_name='Dummy Contact',
                                relationship_to_learner_id='relationship_to_learner.MOTHER', contact_role_id='contact_role.CAREGIVER')),
        ('family_contact', dict(contact_id='DUMMY-C2', learner_id='DUMMY-L2', contact_name='Another Dummy Contact')),
        ('learner_sensitive_details', dict(learner_id='DUMMY-L1', aadhaar_number='DUMMY-NOT-A-REAL-AADHAAR')),
        ('mobilisation_lead', dict(candidate_id='DUMMY-LEAD', learner_id='DUMMY-L1',
                                  current_status_id='lead_status.CONVERTED', assigned_associate_id='DUMMY-STAFF')),
        ('lead_follow_up', dict(followup_id='DUMMY-FOLLOWUP', lead_id='DUMMY-LEAD', owner_staff_id='DUMMY-STAFF')),
        ('partner_organisation', dict(partner_organisation_id='DUMMY-PARTNER', organisation_name='Dummy Partner',
                                     partnership_status_id='partnership_status.MOU_SIGNED')),
        ('mobilisation_activity', dict(activity_id='DUMMY-ACTIVITY', partner_organisation_id='DUMMY-PARTNER',
                                      associate_staff_id='DUMMY-STAFF')),
        ('monthly_target', dict(target_id='DUMMY-TARGET', staff_id='DUMMY-STAFF', month='2026-01-01', contact_target=1)),
        ('report_meeting_log', dict(log_id='DUMMY-MEETING', owner_staff_id='DUMMY-STAFF')),
        ('batch', dict(batch_id='DUMMY-B1', program_id='programme.ILS', class_days='Tue, Thu', max_students=2)),
        ('batch', dict(batch_id='DUMMY-B2', program_id='programme.ILS')),
        ('enrolment', dict(enrolment_id='DUMMY-E1', learner_id='DUMMY-L1', batch_id='DUMMY-B1',
                          supporter_contact_id='DUMMY-C1', total_fee_amount=120, supported_subsidy_amount=20,
                          docs_provided=True, enrolment_date='2026-01-01')),
        ('enrolment', dict(enrolment_id='DUMMY-E2', learner_id='DUMMY-L2', batch_id='DUMMY-B2')),
        ('fee_instalment', dict(instalment_id='DUMMY-I1', enrolment_id='DUMMY-E1', instalment_number=1,
                                amount_due=40, due_date='2026-01-01')),
        ('fee_instalment', dict(instalment_id='DUMMY-I2', enrolment_id='DUMMY-E1', instalment_number=2,
                                amount_due=60, due_date='2026-02-01')),
        ('fee_payment', dict(payment_id='DUMMY-P1', enrolment_id='DUMMY-E1', amount=75,
                            payment_type_id='payment_type.PAYMENT', payment_date='2026-01-02')),
        ('fee_payment', dict(payment_id='DUMMY-R1', enrolment_id='DUMMY-E1', amount=5,
                            payment_type_id='payment_type.REFUND', payment_date='2026-01-03', remarks='Dummy refund')),
        ('standard_topic', dict(topic_id='DUMMY-TOPIC', topic_name='Dummy lesson', session_type_id='session_type.FUNCTIONAL')),
        ('master_programme_schedule', dict(master_programme_schedule_id='DUMMY-TEMPLATE', programme_id='programme.ILS',
                                           template_name='Dummy Curriculum', week_number=1, session_number=1,
                                           topic_id='DUMMY-TOPIC', session_type_id='session_type.FUNCTIONAL')),
        ('batch_schedule', dict(batch_schedule_id='DUMMY-S1', batch_id='DUMMY-B1', week_number=1, session_number=1,
                                master_programme_schedule_id='DUMMY-TEMPLATE', topic_id='DUMMY-TOPIC',
                                actual_session_date='2026-01-01', delivery_status_id='delivery_status.HOLIDAY')),
        ('batch_schedule', dict(batch_schedule_id='DUMMY-S2', batch_id='DUMMY-B1', week_number=1, session_number=2,
                                actual_session_date='2026-01-02', delivery_status_id='delivery_status.DELIVERED')),
        ('batch_schedule', dict(batch_schedule_id='DUMMY-S3', batch_id='DUMMY-B2', week_number=1, session_number=1)),
        # A Holiday log and an off-first-session weekly check deliberately remain accepted.
        ('learner_session_log', dict(learner_session_log_id='DUMMY-LOG1', enrolment_id='DUMMY-E1',
                                     batch_schedule_id='DUMMY-S1', attendance_mark='H', journal_status_id='journal_status.COMPLETE')),
        ('goal', dict(goal_id='DUMMY-G1', enrolment_id='DUMMY-E1', goal_number=1,
                      goal_section_id='goal_section.SMART_GOALS', responsible_contact_id='DUMMY-C1')),
        ('goal_review', dict(goal_review_id='DUMMY-GR1', goal_id='DUMMY-G1', milestone_week=4, faculty_rating_score=3)),
        ('assessment_event', dict(assessment_event_id='DUMMY-A1', enrolment_id='DUMMY-E1',
                                  assessment_type_id='assessment_type.FUNCTIONAL', rubric_version='DUMMY-RUBRIC',
                                  supported_by_contact_id='DUMMY-C1')),
        ('criterion_catalogue', dict(criterion_id='DUMMY-CR1', assessment_type_id='assessment_type.FUNCTIONAL',
                                     rubric_version='DUMMY-RUBRIC', criterion_number=1, criterion_name='Dummy criterion', maximum_score=5)),
        ('criterion_catalogue', dict(criterion_id='DUMMY-CR2', assessment_type_id='assessment_type.BASELINE',
                                     rubric_version='DUMMY-OTHER-RUBRIC', criterion_number=1, criterion_name='Other dummy criterion', maximum_score=5)),
        ('criterion_score', dict(criterion_score_id='DUMMY-CS1', assessment_event_id='DUMMY-A1',
                                 criterion_id='DUMMY-CR1', score_value=4)),
    ]
    out.extend(insert(table, **values) for table, values in records)
    out.append('commit;')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    print(sql(), end='')
