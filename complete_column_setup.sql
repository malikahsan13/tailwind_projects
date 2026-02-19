-- ============================================================================
-- COMPLETE COLUMN SETUP FOR V2 SYNC
-- ============================================================================
-- Run this ONCE before running the V2 sync scripts
-- This adds ALL required columns to insurance_firm table
-- ============================================================================

-- ============================================================================
-- STEP 1: Check which columns already exist
-- ============================================================================

SELECT
    'CHECKING EXISTING COLUMNS' AS step,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'insurance_firm'
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME IN (
      'payer_id_new',
      'name_new',
      'sync_status',
      'sync_details',
      'last_synced_at',
      'matched_via'
  )
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- STEP 2: Add missing columns (run each individually to see errors)
-- ============================================================================

-- Add payer_id_new column
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `payer_id_new` VARCHAR(200) NULL COMMENT 'Correct payer ID from OA (COALESCE of fac, pro, elig)'
AFTER `payer_id`;

-- Add name_new column
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `name_new` VARCHAR(255) NULL COMMENT 'Correct name from OA'
AFTER `name`;

-- Add sync_status column
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `sync_status` VARCHAR(50) NULL COMMENT 'Match status: EXACT_MATCH, PAYER_ID_ONLY, NAME_ONLY, NO_MATCH, NEW_FROM_OA'
AFTER `wc_auto_elig`;

-- Add sync_details column
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `sync_details` TEXT NULL COMMENT 'Detailed sync information'
AFTER `sync_status`;

-- Add last_synced_at column
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `last_synced_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Last sync timestamp'
AFTER `sync_details`;

-- Add matched_via column (IMPORTANT for V2!)
ALTER TABLE `insurance_firm`
ADD COLUMN IF NOT EXISTS `matched_via` VARCHAR(10) NULL COMMENT 'Which column matched: fac, pro, elig, name, or NULL'
AFTER `last_synced_at`;

-- ============================================================================
-- STEP 3: Verify all columns were added successfully
-- ============================================================================

SELECT
    '=== FINAL COLUMN VERIFICATION ===' AS verification,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_COMMENT,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'insurance_firm'
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME IN (
      'payer_id_new',
      'name_new',
      'sync_status',
      'sync_details',
      'last_synced_at',
      'matched_via'
  )
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- STEP 4: Show complete table structure (new columns highlighted)
-- ============================================================================

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CASE
        WHEN COLUMN_NAME IN ('payer_id', 'name') THEN '★ ORIGINAL (preserved)'
        WHEN COLUMN_NAME IN ('payer_id_new', 'name_new', 'sync_status', 'sync_details', 'last_synced_at', 'matched_via') THEN '✓ NEW (added)'
        WHEN COLUMN_NAME LIKE 'payer_id_%' THEN '✓ FROM OA'
        WHEN COLUMN_NAME LIKE '%_enrollment' THEN '✓ FROM OA'
        WHEN COLUMN_NAME LIKE 'non_par_%' OR COLUMN_NAME LIKE 'secondary_ins_%' OR COLUMN_NAME LIKE 'attachment_%' OR COLUMN_NAME LIKE 'wc_auto_%' THEN '✓ FLAG FROM OA'
        ELSE 'OTHER'
    END AS column_type,
    IS_NULLABLE,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'insurance_firm'
  AND TABLE_SCHEMA = DATABASE()
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- COMPLETE! Ready to run V2 sync scripts
-- ============================================================================

SELECT
    '✓ SETUP COMPLETE!' AS status,
    'All required columns added to insurance_firm' AS message,
    'Next: Run revised_v2_pre_flight_check.sql' AS step1,
    'Then: Run revised_v2_sync_script.sql' AS step2,
    'Finally: Run revised_v2_post_sync_cleanup.sql' AS step3;
