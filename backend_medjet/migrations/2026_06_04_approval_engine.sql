SET NAMES utf8mb4;

-- ============ 1) APPROVAL CHAINS ============
CREATE TABLE IF NOT EXISTS `approval_chains` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name_ar` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `request_type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'leave|expense|loan|bonus|warning|document|generic',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `min_amount` decimal(14,2) DEFAULT NULL COMMENT 'Condition: context amount >= this (NULL=no min)',
  `max_amount` decimal(14,2) DEFAULT NULL COMMENT 'Condition: context amount <= this (NULL=no max)',
  `branch_id` int unsigned DEFAULT NULL COMMENT 'Condition: request branch = this (NULL=all branches)',
  `priority` int NOT NULL DEFAULT '0' COMMENT 'Higher wins when multiple chains match',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_chain_tenant_type_active` (`tenant_id`,`request_type`,`is_active`),
  KEY `idx_chain_branch` (`branch_id`),
  CONSTRAINT `approval_chains_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_chains_ibfk_2` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_chains_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ 2) APPROVAL CHAIN STEPS ============
CREATE TABLE IF NOT EXISTS `approval_chain_steps` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `chain_id` int unsigned NOT NULL,
  `step_order` tinyint unsigned NOT NULL COMMENT 'Starts at 1, sequential',
  `approver_type` enum('role','admin') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'role',
  `approver_role` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'When approver_type=role',
  `approver_admin_id` int unsigned DEFAULT NULL COMMENT 'When approver_type=admin',
  `label` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Descriptive name for the step',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_chain_step_order` (`chain_id`,`step_order`),
  KEY `idx_step_tenant` (`tenant_id`),
  KEY `idx_step_admin` (`approver_admin_id`),
  CONSTRAINT `approval_chain_steps_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_chain_steps_ibfk_2` FOREIGN KEY (`chain_id`) REFERENCES `approval_chains` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_chain_steps_ibfk_3` FOREIGN KEY (`approver_admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ 3) APPROVAL REQUESTS ============
CREATE TABLE IF NOT EXISTS `approval_requests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `chain_id` int unsigned DEFAULT NULL COMMENT 'Referential; SET NULL if chain deleted (steps are snapshot)',
  `entity_type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `entity_id` int unsigned NOT NULL,
  `requested_by_admin_id` int unsigned DEFAULT NULL,
  `requested_by_employee_id` int unsigned DEFAULT NULL,
  `context_amount` decimal(14,2) DEFAULT NULL COMMENT 'Amount used for conditional matching (audit)',
  `current_step` tinyint unsigned NOT NULL DEFAULT '1',
  `total_steps` tinyint unsigned NOT NULL,
  `status` enum('pending','approved','rejected','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `decided_at` timestamp NULL DEFAULT NULL COMMENT 'Final decision timestamp',
  PRIMARY KEY (`id`),
  KEY `idx_req_tenant_status` (`tenant_id`,`status`),
  KEY `idx_req_entity` (`tenant_id`,`entity_type`,`entity_id`),
  CONSTRAINT `approval_requests_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_requests_ibfk_2` FOREIGN KEY (`chain_id`) REFERENCES `approval_chains` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ 4) APPROVAL REQUEST STEPS ============
CREATE TABLE IF NOT EXISTS `approval_request_steps` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `request_id` int unsigned NOT NULL,
  `step_order` tinyint unsigned NOT NULL,
  `approver_type` enum('role','admin') COLLATE utf8mb4_unicode_ci NOT NULL,
  `approver_role` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `approver_admin_id` int unsigned DEFAULT NULL,
  `label` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('pending','approved','rejected','skipped') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `decided_by` int unsigned DEFAULT NULL COMMENT 'admins.id who decided this step',
  `decided_at` timestamp NULL DEFAULT NULL,
  `note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_reqstep_order` (`request_id`,`step_order`),
  KEY `idx_reqstep_tenant_status` (`tenant_id`,`status`),
  KEY `idx_reqstep_admin` (`approver_admin_id`),
  CONSTRAINT `approval_request_steps_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_request_steps_ibfk_2` FOREIGN KEY (`request_id`) REFERENCES `approval_requests` (`id`) ON DELETE CASCADE,
  CONSTRAINT `approval_request_steps_ibfk_3` FOREIGN KEY (`approver_admin_id`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============ 5) notifications: add 'approval' category ============
-- decide.php inserts notifications with type='approval' for the next approver.
-- Under STRICT_TRANS_TABLES an unknown enum value errors out (notification lost).
-- 'support' is already live; this re-states it so the column matches schema.sql.
ALTER TABLE `notifications`
  MODIFY COLUMN `type` enum('general','attendance','payroll','leave','warning','system','subscription','invite','support','approval')
  COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'general';
