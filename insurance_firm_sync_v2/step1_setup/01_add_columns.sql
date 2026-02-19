-- ============================================================================
-- STEP 1.1: ADD NEW COLUMNS TO insurance_firm TABLE
-- ============================================================================
-- Purpose: Add all required tracking columns for the sync process
-- Database: MySQL
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Add payer_id_new column (Correct payer ID from OA)
-- ----------------------------------------------------------------------------
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `payer_id_new` VARCHAR(200) NULL
COMMENT 'Correct payer ID from insurance_firm_oa (COALESCE of fac, pro, elig)'
AFTER `payer_id`;

-- ----------------------------------------------------------------------------
-- Add name_new column (Correct name from OA)
-- ----------------------------------------------------------------------------
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `name_new` VARCHAR(255) NULL
COMMENT 'Correct name from insurance_firm_oa'
AFTER `name`;

-- ----------------------------------------------------------------------------
-- Add sync_status column (Track match quality)
-- ----------------------------------------------------------------------------
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `sync_status` VARCHAR(50) NULL
COMMENT 'Match status: EXACT_MATCH, PAYER_ID_ONLY, NAME_ONLY, NO_MATCH, NEW_FROM_OA'
AFTER `wc_auto_elig`;

-- ----------------------------------------------------------------------------
-- Add sync_details column (Detailed sync information)
-- ----------------------------------------------------------------------------
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `sync_details` TEXT NULL
COMMENT 'Detailed sync information and notes'
AFTER `sync_status`;

-- ----------------------------------------------------------------------------
-- Add last_synced_at column (Audit timestamp)
-- ----------------------------------------------------------------------------
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `last_synced_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
COMMENT 'Last sync timestamp for audit purposes'
AFTER `sync_details`;

-- ----------------------------------------------------------------------------
-- Add matched_via column (Track which column matched)
-- ----------------------------------------------------------------------------
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `matched_via` VARCHAR(10) NULL
COMMENT 'Which column matched: fac, pro, elig, name, or NULL'
AFTER `last_synced_at`;

-- ----------------------------------------------------------------------------
-- Confirmation message
-- ----------------------------------------------------------------------------
SELECT
    '✓ COLUMN SETUP COMPLETE' AS status,
    'All 6 new columns added to insurance_firm table' AS message,
    'Next: Run 02_verify_columns.sql to confirm' AS next_step;

-- ----------------------------------------------------------------------------
-- Show added columns
-- ----------------------------------------------------------------------------
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'insurance_firm'
  AND COLUMN_NAME IN (
      'payer_id_new',
      'name_new',
      'sync_status',
      'sync_details',
      'last_synced_at',
      'matched_via'
  )
ORDER BY ORDINAL_POSITION;
