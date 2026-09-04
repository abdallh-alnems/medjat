-- Removes everything inserted by test_all_states.sql. Run in u869543217_permedjat.
USE `u869543217_permedjat`;

DELETE FROM loan_installments WHERE loan_id IN (SELECT id FROM employee_loans WHERE reason LIKE 'TEST%');
DELETE FROM employee_loans      WHERE reason  LIKE 'TEST%';
DELETE FROM leaves              WHERE reason  LIKE 'TEST%';
DELETE FROM break_requests      WHERE reason  LIKE 'TEST%';
DELETE FROM warnings            WHERE reason  LIKE 'TEST%';
DELETE FROM employee_documents  WHERE notes   LIKE 'TEST%';
DELETE FROM asset_custody       WHERE name    LIKE 'TEST%';
DELETE FROM attendance          WHERE notes   LIKE 'TEST%';
DELETE FROM payroll             WHERE month IN ('2020-01','2020-02','2020-03');
DELETE FROM manual_deductions   WHERE reason  LIKE 'TEST%';
DELETE FROM manual_bonuses      WHERE reason  LIKE 'TEST%';
DELETE FROM employee_allowances WHERE label   LIKE 'TEST%';
DELETE FROM support_tickets     WHERE subject LIKE 'TEST%';
DELETE FROM manager_invitations WHERE name    LIKE 'TEST%';
DELETE FROM employee_settlements WHERE notes  LIKE 'TEST%';
DELETE FROM employee_suspensions WHERE reason LIKE 'TEST%';
DELETE FROM employees           WHERE name    LIKE 'TEST%';
