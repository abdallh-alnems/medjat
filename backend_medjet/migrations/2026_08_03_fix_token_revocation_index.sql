-- ============================================
-- Migration: replace a unique index that never did what its name says
-- Date: 2026-08-03
-- Feature: specs/004-web-attendance-checkin (found while testing it)
-- ============================================
--
-- `uniq_active_token_per_emp` was UNIQUE (employee_id, revoked_at), and the name
-- says it limits an employee to one active token. It does not, and never did:
-- MySQL treats NULLs in a unique index as distinct, so any number of rows with
-- revoked_at = NULL — that is, any number of *active* tokens — were always
-- allowed. The one-token rule has only ever been enforced by application code
-- revoking before inserting.
--
-- What the index did enforce was an accident: an employee could not have two
-- tokens revoked in the same second. That is not a rule anyone wanted, and it
-- breaks a correct operation:
--
--     UPDATE employee_auth_tokens SET revoked_at = NOW() WHERE employee_id = ?
--
-- which is what terminating an employee does (app/employees/delete.php,
-- app/settlements/approve.php). It failed with a 1062 duplicate-entry error as
-- soon as an employee held more than one token. Until browser sessions existed
-- an employee only ever had one, so the bug was unreachable — the revocation
-- code even worked around it by revoking a single row found with LIMIT 1, which
-- quietly left the second token alive once two were possible.
--
-- Dropping it therefore removes a constraint that blocked correct behaviour and
-- guaranteed nothing. A plain index keeps the lookups it was also serving.
--
-- If a database-level guarantee is wanted later, the shape to use is one active
-- token per (employee, platform) — NOT per employee, because an employee is now
-- meant to hold a phone session and a browser session at the same time. MySQL 8
-- has no partial indexes, so that needs a STORED generated column such as
-- IF(revoked_at IS NULL, CONCAT(employee_id, ':', platform), NULL) with a unique
-- index on it. Deliberately not done here: it is a schema change on the table
-- every employee authenticates through, and the application-level rule is
-- already correct and now covered by the endpoint tests.

-- Order matters. The foreign key on employee_id is currently satisfied by
-- uniq_active_token_per_emp's leftmost column, so dropping it first fails with
-- "Cannot drop index: needed in a foreign key constraint". The replacement has
-- to exist before the original can go.
ALTER TABLE `employee_auth_tokens`
  ADD KEY `idx_token_employee_revoked` (`employee_id`, `revoked_at`);

ALTER TABLE `employee_auth_tokens`
  DROP INDEX `uniq_active_token_per_emp`;
