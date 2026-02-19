-- ============================================================================
-- ADD matched_via COLUMN - Run this BEFORE the main sync script
-- ============================================================================

-- Step 1: Add matched_via column to insurance_firm table
ALTER TABLE `insurance_firm`
ADD COLUMN `matched_via` VARCHAR(10) NULL COMMENT 'Which column matched: fac, pro, elig, or name'
AFTER `last_synced_at`;

-- Verify the column was added
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'insurance_firm'
  AND COLUMN_NAME = 'matched_via';

-- ============================================================================
-- COMPLETE COLUMN LIST FOR INSURANCE_FIRM
-- ============================================================================

-- Show all new columns that should exist
SELECT
    '=== REQUIRED NEW COLUMNS ===' AS info,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_TYPE
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
-- SUMMARY
-- ============================================================================

SELECT
    'Column Setup Complete!' AS status,
    'Now you can run the main V2 sync script' AS next_step,
    'matched_via will store: fac, pro, elig, name, or NULL' AS description;
