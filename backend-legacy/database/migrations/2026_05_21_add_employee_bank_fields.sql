-- Add bank fields to employees table
ALTER TABLE `employees`
    ADD COLUMN `bank_name` VARCHAR(100) DEFAULT NULL AFTER `face_embedding`,
    ADD COLUMN `bank_account_number` VARCHAR(34) DEFAULT NULL AFTER `bank_name`,
    ADD COLUMN `bank_iban` VARCHAR(34) DEFAULT NULL AFTER `bank_account_number`,
    ADD COLUMN `bank_swift` VARCHAR(11) DEFAULT NULL AFTER `bank_iban`;
