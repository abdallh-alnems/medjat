-- Removes the Expense Claims feature (reimbursements with receipts) entirely.
-- The feature was dropped as out-of-scope; expense reimbursement is better served
-- by dedicated tools. Employee loans/advances (employee_loans, loan_installments)
-- are unaffected — they live in 2026_05_25_add_expenses_and_loans.sql and remain.
-- Safe to run once on the live MySQL 8 (MAMP) database.

DROP TABLE IF EXISTS `expense_claims`;
