-- ============================================
-- Migration: Remove name_ar and owner_phone from tenants
-- Date: May 2026
-- ============================================

SET NAMES utf8mb4;

ALTER TABLE `tenants`
    DROP COLUMN `name_ar`,
    DROP COLUMN `owner_phone`;
