-- Per-employee weekly off days. The add/edit-employee form already collects these
-- (e.g. Friday + Saturday) but the value was silently dropped on save. Stored as a
-- SET so an employee can have zero, one, or several recurring days off, matching the
-- day vocabulary used by `recurring_leaves.day_of_week`.
ALTER TABLE `employees`
    ADD COLUMN `weekly_off_days`
        SET('saturday','sunday','monday','tuesday','wednesday','thursday','friday')
        DEFAULT NULL AFTER `annual_leave_days`;
