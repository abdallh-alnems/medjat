-- Remove the subscriptions & packages (plans) system entirely.
-- Hand-written for live MySQL 8 (no `IF EXISTS` on DROP COLUMN there; run once).
-- Order matters: subscriptions references plans via FK.

DROP TABLE IF EXISTS `subscriptions`;
DROP TABLE IF EXISTS `plans`;

-- Drop the denormalized plan name on tenants.
ALTER TABLE `tenants` DROP COLUMN `plan`;

-- Retire the 'subscription' notification type (no producer left).
UPDATE `notifications` SET `type` = 'general' WHERE `type` = 'subscription';
ALTER TABLE `notifications`
  MODIFY COLUMN `type` enum('general','attendance','payroll','leave','warning','system','invite','support','approval')
  COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'general';
