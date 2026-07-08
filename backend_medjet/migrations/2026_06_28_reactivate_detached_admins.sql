-- Removal now DETACHES an admin (tenant_id = NULL) but keeps the account active,
-- so the person can sign back in and onboard into another company.
--
-- The previous flow disabled removed accounts (is_active = 0), which permanently
-- blocked their login. Re-activate any such previously-removed accounts. A NULL
-- tenant with is_active = 0 can only be a removed admin (fresh signups are
-- created with is_active = 1), so this is safe.

UPDATE admins
SET is_active = 1,
    role = 'pending'
WHERE tenant_id IS NULL
  AND is_active = 0;
