-- Tiered late-arrival deductions.
-- Each tenant defines a ladder of thresholds: when an employee's late minutes
-- reach a tier's threshold, the matching deduction (expressed as a fraction of
-- a working day) applies. PayrollCalculator picks the HIGHEST threshold that is
-- <= the recorded late minutes ("ladder" matching).
--
-- Paired with deduction_rules row  rule_key = 'late_type' value = 'tiered'.
CREATE TABLE IF NOT EXISTS `late_deduction_tiers` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `threshold_minutes` int unsigned NOT NULL,
  `deduction_days` decimal(5,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_tenant_threshold` (`tenant_id`,`threshold_minutes`),
  CONSTRAINT `late_deduction_tiers_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
