-- Asset & custody management. The admin assigns a custody item (cash custody,
-- equipment, device, vehicle, document, ...) to an employee. The employee can
-- later request its return (employee app), and the admin confirms or rejects
-- the return. Optional photos document the item at hand-over and at return.
-- Powers the "Assets & Custody Management" feature. Safe to run once.

CREATE TABLE IF NOT EXISTS `asset_custody` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `type` enum('money','equipment','device','vehicle','document','other') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'equipment',
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `value` decimal(12,2) DEFAULT NULL,
  `currency` varchar(8) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'SAR',
  `serial_no` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quantity` int unsigned NOT NULL DEFAULT '1',
  `assign_photo_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `return_photo_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('assigned','return_requested','returned') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'assigned',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `return_note` text COLLATE utf8mb4_unicode_ci,
  `rejection_reason` text COLLATE utf8mb4_unicode_ci,
  `assigned_at` date NOT NULL,
  `assigned_by` int unsigned DEFAULT NULL,
  `return_requested_at` timestamp NULL DEFAULT NULL,
  `returned_at` timestamp NULL DEFAULT NULL,
  `return_approved_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_asset_tenant_status` (`tenant_id`,`status`),
  KEY `idx_asset_employee` (`employee_id`),
  KEY `assigned_by` (`assigned_by`),
  KEY `return_approved_by` (`return_approved_by`),
  CONSTRAINT `asset_custody_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `asset_custody_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `asset_custody_ibfk_3` FOREIGN KEY (`assigned_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `asset_custody_ibfk_4` FOREIGN KEY (`return_approved_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
