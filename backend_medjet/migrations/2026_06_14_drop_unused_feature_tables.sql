-- ============================================================================
-- OPTIONAL / DESTRUCTIVE — RUN MANUALLY ON THE LIVE DB ONLY WHEN READY.
-- Reclaims tables for features whose endpoints + models were removed
-- (advanced analytics, engagement = announcements/kudos/surveys, recruitment).
--
-- This is NOT auto-applied. Take a DB backup first. There is no automatic
-- rollback — restore from backup if needed.
--
-- DO NOT add onboarding_* or approval_* tables here: they are still in use
-- (onboarding tasks are generated on hire; leaves route through the approval
-- engine).
-- ============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- Engagement (announcements + kudos + surveys)
DROP TABLE IF EXISTS announcement_reads;
DROP TABLE IF EXISTS announcements;
DROP TABLE IF EXISTS kudos;
DROP TABLE IF EXISTS survey_answers;
DROP TABLE IF EXISTS survey_completions;
DROP TABLE IF EXISTS survey_responses;
DROP TABLE IF EXISTS survey_questions;
DROP TABLE IF EXISTS surveys;

-- Recruitment (ATS) — onboarding tables in the same original migration are KEPT
DROP TABLE IF EXISTS candidates;
DROP TABLE IF EXISTS job_openings;

-- Advanced analytics
DROP TABLE IF EXISTS analytics_dashboards;

SET FOREIGN_KEY_CHECKS = 1;
