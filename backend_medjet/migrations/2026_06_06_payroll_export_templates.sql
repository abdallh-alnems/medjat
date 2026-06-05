-- قوالب تصدير الرواتب المخصّصة (CSV مسطّح) لكل شركة
-- ⚠️ MySQL 8: بدون "IF NOT EXISTS" مع الأعمدة — يُشغّل مرة واحدة لكل قاعدة
CREATE TABLE IF NOT EXISTS `payroll_export_templates` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'اسم القالب كما يراه المستخدم',
  `delimiter` varchar(4) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ',' COMMENT 'الفاصل: , ; | \t',
  `include_bom` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'إضافة UTF-8 BOM',
  `include_header_row` tinyint(1) NOT NULL DEFAULT 1 COMMENT 'كتابة صف عناوين الأعمدة',
  `decimal_places` tinyint unsigned NOT NULL DEFAULT 2 COMMENT 'منازل عشرية للحقول الرقمية',
  `columns` json NOT NULL COMMENT 'مصفوفة أعمدة: [{"label":"..","field":"net_salary"}]',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_export_tpl_tenant` (`tenant_id`, `is_active`),
  CONSTRAINT `fk_export_tpl_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
