-- ============================================================
-- Migration: Letters & Certificates feature (طلبات الخطابات والشهادات)
-- Date: 2026-05-21
-- Idempotent-ish: new tables use IF NOT EXISTS. The tenant column
-- additions are guarded so the script is safe to re-run on MySQL 8
-- (which lacks ADD COLUMN IF NOT EXISTS).
-- ============================================================

-- ── Tenant branding + company text data for letters ──────────
-- Re-runnable column adds (skip if column already exists).
SET @ddl := (
  SELECT IF(
    COUNT(*) = 0,
    'ALTER TABLE `tenants`
       ADD COLUMN `stamp_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT ''Company stamp image for generated letters'',
       ADD COLUMN `signature_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT ''Authorized signatory image for generated letters'',
       ADD COLUMN `commercial_register` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT ''Commercial registration number shown on letters'',
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

-- ── Document templates (system defaults + custom) ────────────
CREATE TABLE IF NOT EXISTS `document_templates` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `template_key` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name_ar` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name_en` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `body_ar` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `body_en` text COLLATE utf8mb4_unicode_ci,
  `is_system` tinyint(1) NOT NULL DEFAULT '0',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `sort_order` int NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_doctpl_tenant` (`tenant_id`),
  KEY `idx_doctpl_tenant_key` (`tenant_id`,`template_key`),
  CONSTRAINT `document_templates_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Document requests (employee request -> admin approve/reject) ──
CREATE TABLE IF NOT EXISTS `document_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `template_id` int unsigned DEFAULT NULL,
  `doc_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('pending','approved','rejected') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `extra_fields` json DEFAULT NULL,
  `rejection_reason` text COLLATE utf8mb4_unicode_ci,
  `pdf_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requested_by_employee` tinyint(1) NOT NULL DEFAULT '0',
  `issued_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `processed_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_docreq_tenant_status` (`tenant_id`,`status`),
  KEY `idx_docreq_employee` (`employee_id`),
  KEY `idx_docreq_template` (`template_id`),
  KEY `issued_by` (`issued_by`),
  CONSTRAINT `document_requests_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `document_requests_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `document_requests_ibfk_3` FOREIGN KEY (`template_id`) REFERENCES `document_templates` (`id`) ON DELETE SET NULL,
  CONSTRAINT `document_requests_ibfk_4` FOREIGN KEY (`issued_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
