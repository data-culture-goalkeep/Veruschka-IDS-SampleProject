-- Approved demo-only upper-limit expansion; lower limits and other sections unchanged.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
alter table ids.goal_review drop constraint goal_review_check;
alter table ids.goal_review add constraint goal_review_check check (
  case context_section_key
    when 'goal_section.SMART_GOALS' then
      (faculty_rating_score between 1 and 5) and (family_rating_score between 1 and 5)
    when 'goal_section.FUNCTIONAL_LEARNING' then
      (faculty_rating_score between 0 and 5) and (family_rating_score between 0 and 5)
    when 'goal_section.HOSPITALITY' then
      (faculty_rating_score between 0 and 5) and (family_rating_score between 0 and 5)
    else true
  end
);
commit;
