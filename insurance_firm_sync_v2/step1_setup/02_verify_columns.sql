-- ============================================================================
-- STEP 1.2: VERIFY COLUMNS WERE ADDED SUCCESSFULLY
-- ============================================================================
-- Purpose: Confirm all required columns exist and are properly configured
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Verification 1: Check all new columns exist
-- ----------------------------------------------------------------------------
SELECT
    '=== NEW COLUMNS VERIFICATION ===' AS check_type,
    COUNT(*) AS columns_found,
    CASE
        WHEN COUNT(*) = 6 THEN '✓ ALL 6 COLUMNS FOUND'
        ELSE CONCAT('✗ MISSING: ', 6 - COUNT(*), ' COLUMNS')
    END AS status
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
  );

-- ----------------------------------------------------------------------------
-- Verification 2: Show column details
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

-- ----------------------------------------------------------------------------
-- Verification 3: Show complete table structure with context
-- ----------------------------------------------------------------------------
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CASE
        WHEN COLUMN_NAME = 'payer_id' THEN '★ ORIGINAL (preserved)'
        WHEN COLUMN_NAME = 'name' THEN '★ ORIGINAL (preserved)'
        WHEN COLUMN_NAME IN ('payer_id_new', 'name_new', 'sync_status', 'sync_details', 'last_synced_at', 'matched_via') THEN '✓ NEW (added)'
        WHEN COLUMN_NAME = 'payer_id_fac' THEN '✓ FROM OA'
        WHEN COLUMN_NAME = 'payer_id_pro' THEN '✓ FROM OA'
        WHEN COLUMN_NAME = 'payer_id_elig' THEN '✓ FROM OA'
        WHEN COLUMN_NAME LIKE '%_enrollment' THEN '✓ FROM OA'
        WHEN COLUMN_NAME LIKE 'non_par_%' THEN '✓ FLAG FROM OA'
        WHEN COLUMN_NAME LIKE 'secondary_ins_%' THEN '✓ FLAG FROM OA'
        WHEN COLUMN_NAME LIKE 'attachment_%' THEN '✓ FLAG FROM OA'
        WHEN COLUMN_NAME LIKE 'wc_auto_%' THEN '✓ FLAG FROM OA'
        ELSE 'OTHER'
    END AS column_type,
    IS_NULLABLE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'insurance_firm'
ORDER BY ORDINAL_POSITION;

-- ----------------------------------------------------------------------------
-- Verification 4: Sample current data (before sync)
-- ----------------------------------------------------------------------------
SELECT
    '=== CURRENT DATA SAMPLE (BEFORE SYNC) ===' AS info,
    firm_id,
    payer_id,
    name,
    payer_id_new,
    name_new,
    sync_status,
    matched_via
FROM insurance_firm
LIMIT 5;

-- ----------------------------------------------------------------------------
-- Final status
-- ----------------------------------------------------------------------------
SELECT
    CASE
        WHEN (
            SELECT COUNT(*)
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = 'insurance_firm'
              AND COLUMN_NAME IN ('payer_id_new', 'name_new', 'sync_status',
                                  'sync_details', 'last_synced_at', 'matched_via')
        ) = 6 THEN
            '✓ SETUP VERIFIED - ALL COLUMNS PRESENT'
        ELSE
            '✗ SETUP INCOMPLETE - MISSING COLUMNS'
    END AS final_status,
    'Ready to proceed to STEP 2: Pre-Sync Analysis' AS next_step;

-- ----------------------------------------------------------------------------
-- Row count baseline
-- ----------------------------------------------------------------------------
SELECT
    '=== BASELINE METRICS ===' AS baseline,
    (SELECT COUNT(*) FROM insurance_firm) AS insurance_firm_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) AS insurance_firm_oa_count,
    (SELECT COUNT(*) FROM patient_insurance) AS patient_insurance_count,
    (SELECT COUNT(*) FROM insurance_firm WHERE payer_id IS NOT NULL) AS firms_with_payer_id,
    (SELECT COUNT(*) FROM insurance_firm WHERE name IS NOT NULL) AS firms_with_name;
