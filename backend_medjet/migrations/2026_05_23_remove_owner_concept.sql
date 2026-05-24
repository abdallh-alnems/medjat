-- Remove the "company owner" concept.
-- Companies are managed by roles & permissions, not a single owner.
-- The company creator simply receives the highest role (general_manager),
-- and that role can be granted to anyone via invitation.

-- 1) Drop the owner columns (and the index that depends on owner_email) from tenants.
ALTER TABLE `tenants` DROP INDEX `idx_tenant_email`;
ALTER TABLE `tenants`
  DROP COLUMN `owner_name`,
  DROP COLUMN `owner_email`;

-- 2) Allow the highest role to be granted through an invitation,
--    so any admin can be elevated to full access (no exclusive owner).
ALTER TABLE `manager_invitations`
  MODIFY COLUMN `role`
  enum('general_manager','hr','branch_manager','attendance','viewer')
  COLLATE utf8mb4_unicode_ci NOT NULL;
