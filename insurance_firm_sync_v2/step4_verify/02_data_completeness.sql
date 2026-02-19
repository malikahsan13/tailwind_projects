-- ============================================================================
-- STEP 4.2: DATA COMPLETENESS CHECK
-- ============================================================================
-- Purpose: Verify all required columns are populated
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Overall completeness check
-- ----------------------------------------------------------------------------
SELECT
    '=== OVERALL COMPLETENESS ===' AS completeness_check,
    SUM(CASE WHEN payer_id_new IS NOT NULL THEN 1 ELSE 0 END) AS has_payer_id_new,
    SUM(CASE WHEN name_new IS NOT NULL THEN 1 ELSE 0 END) AS has_name_new,
    SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) AS has_fac,
    SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) AS has_pro,
    SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) AS has_elig,
    COUNT(*) AS total_records,
    ROUND(SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS fac_percentage,
    ROUND(SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pro_percentage,
    ROUND(SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS elig_percentage
FROM insurance_firm;

-- ----------------------------------------------------------------------------
-- Completeness by category
-- ----------------------------------------------------------------------------
SELECT
    '=== COMPLETENESS BY PAY TYPE ===' AS pay_type,
    'Facility Payer IDs' AS category,
    COUNT(*) AS total_records,
    SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) AS populated,
    SUM(CASE WHEN payer_id_fac IS NULL THEN 1 ELSE 0 END) AS missing,
    ROUND(SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS completeness_percentage
FROM insurance_firm

UNION ALL

SELECT
    '=== COMPLETENESS BY PAY TYPE ===' AS pay_type,
    'Professional Payer IDs' AS category,
    COUNT(*) AS total_records,
    SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) AS populated,
    SUM(CASE WHEN payer_id_pro IS NULL THEN 1 ELSE 0 END) AS missing,
    ROUND(SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS completeness_percentage
FROM insurance_firm

UNION ALL

SELECT
    '=== COMPLETENESS BY PAY TYPE ===' AS pay_type,
    'Eligibility Payer IDs' AS category,
    COUNT(*) AS total_records,
    SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) AS populated,
    SUM(CASE WHEN payer_id_elig IS NULL THEN 1 ELSE 0 END) AS missing,
    ROUND(SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS completeness_percentage
FROM insurance_firm;

-- ----------------------------------------------------------------------------
-- Records with all three payer IDs
-- ----------------------------------------------------------------------------
SELECT
    '=== ALL THREE PAYER IDs POPULATED ===' AS complete_check,
    COUNT(*) AS records_with_all_three,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage,
    CASE
        WHEN COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm) >= 95 THEN '✓ EXCELLENT'
        WHEN COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm) >= 80 THEN '✓ GOOD'
        ELSE '⚠ NEEDS ATTENTION'
    END AS status
FROM insurance_firm
WHERE payer_id_fac IS NOT NULL
  AND payer_id_pro IS NOT NULL
  AND payer_id_elig IS NOT NULL;

-- ----------------------------------------------------------------------------
-- Records with incomplete data
-- ----------------------------------------------------------------------------
SELECT
    '=== INCOMPLETE RECORDS ===' AS incomplete_check,
    COUNT(*) AS incomplete_count,
    CASE
        WHEN COUNT(*) = 0 THEN '✓ ALL RECORDS COMPLETE'
        WHEN COUNT(*) <= 5 THEN '⚠ Few incomplete records'
        ELSE '⚠ MANY incomplete records - review needed'
    END AS status
FROM insurance_firm
WHERE payer_id_fac IS NULL
   OR payer_id_pro IS NULL
   OR payer_id_elig IS NULL;

-- Show sample of incomplete records
SELECT
    firm_id,
    payer_id,
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig,
    sync_status,
    CASE
        WHEN payer_id_fac IS NULL AND payer_id_pro IS NULL AND payer_id_elig IS NULL THEN
            'CRITICAL: All payer IDs missing'
        WHEN payer_id_fac IS NULL THEN 'Missing facility'
        WHEN payer_id_pro IS NULL THEN 'Missing professional'
        WHEN payer_id_elig IS NULL THEN 'Missing eligibility'
        ELSE 'Multiple missing'
    END AS missing_type
FROM insurance_firm
WHERE payer_id_fac IS NULL
   OR payer_id_pro IS NULL
   OR payer_id_elig IS NULL
ORDER BY name
LIMIT 20;

-- ----------------------------------------------------------------------------
-- payer_id_new source breakdown
-- ----------------------------------------------------------------------------
SELECT
    '=== PAYER_ID_NEW SOURCE ===' AS source_breakdown,
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'From fac'
        WHEN payer_id_pro IS NOT NULL THEN 'From pro'
        WHEN payer_id_elig IS NOT NULL THEN 'From elig'
        ELSE 'All NULL'
    END AS payer_id_source,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
WHERE sync_status IS NOT NULL
GROUP BY
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'From fac'
        WHEN payer_id_pro IS NOT NULL THEN 'From pro'
        WHEN payer_id_elig IS NOT NULL THEN 'From elig'
        ELSE 'All NULL'
    END
ORDER BY count DESC;

-- ----------------------------------------------------------------------------
-- NULL columns check
-- ----------------------------------------------------------------------------
SELECT
    '=== NULL COLUMN ANALYSIS ===' AS null_analysis,
    'payer_id_new' AS column_name,
    SUM(CASE WHEN payer_id_new IS NULL THEN 1 ELSE 0 END) AS null_count,
    ROUND(SUM(CASE WHEN payer_id_new IS NULL THEN 1 ELSE 0 END) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS null_percentage
FROM insurance_firm

UNION ALL

SELECT
    '=== NULL COLUMN ANALYSIS ===' AS null_analysis,
    'name_new' AS column_name,
    SUM(CASE WHEN name_new IS NULL THEN 1 ELSE 0 END) AS null_count,
    ROUND(SUM(CASE WHEN name_new IS NULL THEN 1 ELSE 0 END) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS null_percentage
FROM insurance_firm

UNION ALL

SELECT
    '=== NULL COLUMN ANALYSIS ===' AS null_analysis,
    'matched_via' AS column_name,
    SUM(CASE WHEN matched_via IS NULL THEN 1 ELSE 0 END) AS null_count,
    ROUND(SUM(CASE WHEN matched_via IS NULL THEN 1 ELSE 0 END) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS null_percentage
FROM insurance_firm

UNION ALL

SELECT
    '=== NULL COLUMN ANALYSIS ===' AS null_analysis,
    'sync_status' AS column_name,
    SUM(CASE WHEN sync_status IS NULL THEN 1 ELSE 0 END) AS null_count,
    ROUND(SUM(CASE WHEN sync_status IS NULL THEN 1 ELSE 0 END) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS null_percentage
FROM insurance_firm;

-- ----------------------------------------------------------------------------
-- Data quality score
-- ----------------------------------------------------------------------------
SELECT
    '=== DATA QUALITY SCORE ===' AS quality_score,
    ROUND(
        (
            SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) * 1.0 +
            SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) * 1.0 +
            SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) * 1.0
        ) * 100.0 /
        ((SELECT COUNT(*) FROM insurance_firm) * 3),
        2
    ) AS overall_quality_percentage,
    CASE
        WHEN (
            SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) * 1.0 +
            SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) * 1.0 +
            SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) * 1.0
        ) * 100.0 / ((SELECT COUNT(*) FROM insurance_firm) * 3) >= 95 THEN '✓ EXCELLENT'
        WHEN (
            SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) * 1.0 +
            SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) * 1.0 +
            SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) * 1.0
        ) * 100.0 / ((SELECT COUNT(*) FROM insurance_firm) * 3) >= 80 THEN '✓ GOOD'
        WHEN (
            SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) * 1.0 +
            SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) * 1.0 +
            SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) * 1.0
        ) * 100.0 / ((SELECT COUNT(*) FROM insurance_firm) * 3) >= 60 THEN '⚠ FAIR'
        ELSE '⚠ POOR'
    END AS quality_rating
FROM insurance_firm;
