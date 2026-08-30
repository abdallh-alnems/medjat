-- ============================================================
-- Migration: Company branding/profile columns
-- Date: 2026-05-21
-- NOTE: The Letters & Certificates and e-signature features were
-- removed; their tables (document_templates, document_requests,
-- signature_requests, signature_parties) are no longer created.
-- These tenant columns are retained because Company Settings and
-- payslip branding use them (logo/stamp/signature, CR, address, phone).
-- Guarded so the script is safe to re-run on MySQL 8.
-- ============================================================

SET @ddl := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE `tenants`
       ADD COLUMN `stamp_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT ''Company stamp image'',
       ADD COLUMN `signature_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT ''Authorized signatory image'',
       ADD COLUMN `commercial_register` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT ''Commercial registration number'',
       ADD COLUMN `company_address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
       ADD COLUMN `company_phone` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL',
    'SELECT 1'
  )
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'tenants'
    AND COLUMN_NAME = 'stamp_url'
);
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;
