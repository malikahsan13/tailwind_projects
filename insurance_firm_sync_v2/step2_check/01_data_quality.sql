-- ============================================================================
-- STEP 2.1: DATA QUALITY CHECK
-- ============================================================================
-- Purpose: Analyze current data quality before running sync
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Check 1: insurance_firm data quality
-- ----------------------------------------------------------------------------
SELECT
    '=== INSURANCE_FIRM DATA QUALITY ===' AS check_name,
    COUNT(*) AS total_records,
    SUM(CASE WHEN payer_id IS NULL THEN 1 ELSE 0 END) AS null_payer_id,
    SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_name,
    SUM(CASE WHEN payer_id IS NOT NULL AND name IS NOT NULL THEN 1 ELSE 0 END) AS complete_records,
    ROUND(
        SUM(CASE WHEN payer_id IS NOT NULL AND name IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS completeness_percentage;

-- ----------------------------------------------------------------------------
-- Check 2: insurance_firm_oa data quality
-- ----------------------------------------------------------------------------
SELECT
    '=== INSURANCE_FIRM_OA DATA QUALITY ===' AS check_name,
    COUNT(*) AS total_records,
    SUM(CASE WHEN payer_id IS NULL THEN 1 ELSE 0 END) AS null_payer_id,
    SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_name,
    SUM(CASE WHEN payer_id_fac IS NULL THEN 1 ELSE 0 END) AS null_payer_id_fac,
    SUM(CASE WHEN payer_id_pro IS NULL THEN 1 ELSE 0 END) AS null_payer_id_pro,
    SUM(CASE WHEN payer_id_elig IS NULL THEN 1 ELSE 0 END) AS null_payer_id_elig,
    ROUND(
        SUM(CASE WHEN payer_id_fac IS NOT NULL OR payer_id_pro IS NOT NULL OR payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS has_any_payer_id_percentage;

-- ----------------------------------------------------------------------------
-- Check 3: payer_id source breakdown in OA
-- ----------------------------------------------------------------------------
SELECT
    '=== OA PAYER_ID SOURCE BREAKDOWN ===' AS check_name,
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'From fac'
        WHEN payer_id_pro IS NOT NULL THEN 'From pro'
        WHEN payer_id_elig IS NOT NULL THEN 'From elig'
        ELSE 'All NULL'
    END AS payer_id_source,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm_oa), 2) AS percentage
FROM insurance_firm_oa
GROUP BY
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'From fac'
        WHEN payer_id_pro IS NOT NULL THEN 'From pro'
        WHEN payer_id_elig IS NOT NULL THEN 'From elig'
        ELSE 'All NULL'
    END
ORDER BY count DESC;

-- ----------------------------------------------------------------------------
-- Check 4: Duplicate detection in insurance_firm
-- ----------------------------------------------------------------------------
SELECT
    '=== DUPLICATE PAYER_IDS IN INSURANCE_FIRM ===' AS check_name,
    payer_id,
    COUNT(*) AS duplicate_count,
    STRING_AGG(DISTINCT name, ', ') AS different_names
FROM insurance_firm
WHERE payer_id IS NOT NULL
GROUP BY payer_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Check 5: Duplicate detection in insurance_firm_oa
-- ----------------------------------------------------------------------------
SELECT
    '=== DUPLICATE NAMES IN INSURANCE_FIRM_OA ===' AS check_name,
    name,
    COUNT(*) AS duplicate_count,
    STRING_AGG(DISTINCT COALESCE(payer_id_fac, payer_id_pro, payer_id_elig, 'NULL'), ', ') AS different_payer_ids
FROM insurance_firm_oa
WHERE name IS NOT NULL
GROUP BY name
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Check 6: Names with whitespace issues
-- ----------------------------------------------------------------------------
SELECT
    '=== NAMES WITH WHITESPACE ISSUES ===' AS check_name,
    COUNT(*) AS count,
    'These names may need trimming' AS note
FROM insurance_firm
WHERE name LIKE '%  %'  -- Double spaces
   OR name LIKE ' %'    -- Leading space
   OR name LIKE ' %'    -- Trailing space
LIMIT 1;

-- Show sample of problematic names
SELECT
    firm_id,
    payer_id,
    '"' || name || '"' AS name_with_quotes,
    LENGTH(name) - LENGTH(REPLACE(name, ' ', '')) AS space_count
FROM insurance_firm
WHERE name LIKE '%  %' OR name LIKE ' %' OR name LIKE ' %'
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Check 7: NULL payer analysis
-- ----------------------------------------------------------------------------
SELECT
    '=== NULL PAYER_ID ANALYSIS ===' AS check_name,
    COUNT(*) AS total_firms_with_null_payer_id,
    'Check if these firms have fac/pro/elig IDs' AS note
FROM insurance_firm
WHERE payer_id IS NULL;

-- Show sample
SELECT
    firm_id,
    payer_id,
    name
FROM insurance_firm
WHERE payer_id IS NULL
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Summary
-- ----------------------------------------------------------------------------
SELECT
    '=== DATA QUALITY SUMMARY ===' AS summary,
    CONCAT(
        'insurance_firm: ',
        (SELECT COUNT(*) FROM insurance_firm),
        ' records, ',
        (SELECT COUNT(*) FROM insurance_firm WHERE payer_id IS NOT NULL AND name IS NOT NULL),
        ' complete (',
        ROUND((SELECT COUNT(*) FROM insurance_firm WHERE payer_id IS NOT NULL AND name IS NOT NULL) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2),
        '%)'
    ) AS firm_quality;

SELECT
    '=== DATA QUALITY SUMMARY ===' AS summary,
    CONCAT(
        'insurance_firm_oa: ',
        (SELECT COUNT(*) FROM insurance_firm_oa),
        ' records, ',
        (SELECT COUNT(*) FROM insurance_firm_oa WHERE payer_id_fac IS NOT NULL OR payer_id_pro IS NOT NULL OR payer_id_elig IS NOT NULL),
        ' have at least one payer ID (',
        ROUND((SELECT COUNT(*) FROM insurance_firm_oa WHERE payer_id_fac IS NOT NULL OR payer_id_pro IS NOT NULL OR payer_id_elig IS NOT NULL) * 100.0 / (SELECT COUNT(*) FROM insurance_firm_oa), 2),
        '%)'
    ) AS oa_quality;
