SET NAMES utf8mb4;

-- ============ 1) EMPLOYEE AVAILABILITY ============
CREATE TABLE IF NOT EXISTS `employee_availability` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `kind` enum('weekly','date') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'weekly',
  `day_of_week` tinyint unsigned DEFAULT NULL COMMENT '0=Sun..6=Sat',
  `specific_date` date DEFAULT NULL COMMENT 'for kind=date',
  `availability` enum('available','preferred','unavailable') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'available',
  `start_time` time DEFAULT NULL,
  `end_time` time DEFAULT NULL,
  `note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_avail_tenant_emp` (`tenant_id`,`employee_id`,`kind`),
  KEY `idx_avail_date` (`specific_date`),
  CONSTRAINT `employee_availability_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `employee_availability_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ 2) OPEN SHIFTS ============
CREATE TABLE IF NOT EXISTS `open_shifts` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL COMMENT 'NULL = all branches eligible',
  `shift_id` int unsigned NOT NULL,
  `work_date` date NOT NULL,
  `slots` tinyint unsigned NOT NULL DEFAULT '1',
  `slots_filled` tinyint unsigned NOT NULL DEFAULT '0',
  `status` enum('open','filled','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'open',
  `notes` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_openshift_tenant_status` (`tenant_id`,`status`,`work_date`),
  KEY `idx_openshift_branch` (`branch_id`),
  CONSTRAINT `open_shifts_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shifts_ibfk_2` FOREIGN KEY (`shift_id`) REFERENCES `shifts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shifts_ibfk_3` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shifts_ibfk_4` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ 3) OPEN SHIFT CLAIMS ============
CREATE TABLE IF NOT EXISTS `open_shift_claims` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `open_shift_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `status` enum('pending','approved','rejected','withdrawn') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `decided_by` int unsigned DEFAULT NULL,
  `decided_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_claim_shift_emp` (`open_shift_id`,`employee_id`),
  KEY `idx_claim_tenant_status` (`tenant_id`,`status`),
  KEY `idx_claim_employee` (`employee_id`),
  CONSTRAINT `open_shift_claims_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shift_claims_ibfk_2` FOREIGN KEY (`open_shift_id`) REFERENCES `open_shifts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shift_claims_ibfk_3` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `open_shift_claims_ibfk_4` FOREIGN KEY (`decided_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ 4) SHIFT SWAP REQUESTS ============
CREATE TABLE IF NOT EXISTS `shift_swap_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `requester_employee_id` int unsigned NOT NULL,
  `requester_date` date NOT NULL,
  `target_employee_id` int unsigned NOT NULL,
  `target_date` date NOT NULL,
  `status` enum('pending_target','pending_manager','approved','rejected','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending_target',
  `requester_note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_responded_at` timestamp NULL DEFAULT NULL,
  `decided_by` int unsigned DEFAULT NULL,
  `decided_at` timestamp NULL DEFAULT NULL,
  `decision_note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_swap_tenant_status` (`tenant_id`,`status`),
  KEY `idx_swap_requester` (`requester_employee_id`),
  KEY `idx_swap_target` (`target_employee_id`),
  CONSTRAINT `shift_swap_requests_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `shift_swap_requests_ibfk_2` FOREIGN KEY (`requester_employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `shift_swap_requests_ibfk_3` FOREIGN KEY (`target_employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `shift_swap_requests_ibfk_4` FOREIGN KEY (`decided_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
