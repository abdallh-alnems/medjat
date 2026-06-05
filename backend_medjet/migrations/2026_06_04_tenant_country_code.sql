-- إضافة رمز الدولة للشركة (ISO 3166-1 alpha-2)
-- ⚠️ MySQL 8 لا يدعم "ADD COLUMN IF NOT EXISTS" — هذا ملف يدوي يُشغّل مرة واحدة
ALTER TABLE `tenants`
  ADD COLUMN `country_code` CHAR(2) NULL DEFAULT 'EG'
  COMMENT 'ISO 3166-1 alpha-2; يحدّد مُصدِّر الرواتب الافتراضي' AFTER `currency`;

-- املأ الشركات الحالية بمصر كافتراض آمن
UPDATE `tenants` SET `country_code` = 'EG' WHERE `country_code` IS NULL;
