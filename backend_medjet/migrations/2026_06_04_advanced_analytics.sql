-- ============ (1) فجوة تاريخ الإنهاء (ضرورية للدوران/القوى العاملة) ============
-- MySQL 8: لا ADD COLUMN IF NOT EXISTS. شغّل مرة واحدة فقط لكل قاعدة.
ALTER TABLE `employees`
  ADD COLUMN `terminated_at` DATE NULL DEFAULT NULL COMMENT 'تاريخ إنهاء الخدمة — يُستخدم لحساب الدوران والقوى العاملة' AFTER `auto_terminate_at`;

ALTER TABLE `employees`
  ADD KEY `idx_emp_terminated_at` (`tenant_id`,`terminated_at`);

-- Backfill للبيانات التاريخية: قدّر تاريخ الإنهاء من deleted_at ثم updated_at.
UPDATE `employees`
   SET `terminated_at` = DATE(COALESCE(`deleted_at`, `updated_at`))
 WHERE `status` = 'terminated' AND `terminated_at` IS NULL;

-- ============ (2) اللوحات القابلة للتخصيص ============
CREATE TABLE IF NOT EXISTS `analytics_dashboards` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `admin_id` int unsigned NOT NULL COMMENT 'صاحب اللوحة — لكل مسؤول لوحته',
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Default',
  `layout` json NOT NULL COMMENT 'مصفوفة widgets: [{key,type,filters,position,size}]',
  `is_default` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_dash_tenant_admin` (`tenant_id`,`admin_id`),
  CONSTRAINT `analytics_dashboards_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `analytics_dashboards_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
