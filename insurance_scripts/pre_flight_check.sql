-- ============================================================================
-- PRE-FLIGHT CHECK - Run BEFORE executing sync script
-- ============================================================================
-- This script helps you understand your data and predict sync results
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CHECK 1: Table Row Counts
-- ----------------------------------------------------------------------------
SELECT
    'TABLE ROW COUNTS' AS check_type,
    (SELECT COUNT(*) FROM insurance_firm) AS insurance_firm_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) AS insurance_firm_oa_count,
    (SELECT COUNT(*) FROM patient_insurance) AS patient_insurance_count;

-- ----------------------------------------------------------------------------
-- CHECK 2: Current Data Quality in insurance_firm
-- ----------------------------------------------------------------------------
SELECT
    'INSURANCE_FIRM DATA QUALITY' AS check_type,
    SUM(CASE WHEN payer_id IS NULL THEN 1 ELSE 0 END) AS null_payer_id,
    SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_name,
    SUM(CASE WHEN payer_id IS NOT NULL AND name IS NOT NULL THEN 1 ELSE 0 END) AS complete_records,
    COUNT(*) AS total_records;

-- ----------------------------------------------------------------------------
-- CHECK 3: Current Data Quality in insurance_firm_oa
-- ----------------------------------------------------------------------------
SELECT
    'INSURANCE_FIRM_OA DATA QUALITY' AS check_type,
    SUM(CASE WHEN payer_id IS NULL THEN 1 ELSE 0 END) AS null_payer_id,
    SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_name,
    SUM(CASE WHEN payer_id_fac IS NULL THEN 1 ELSE 0 END) AS null_payer_id_fac,
    SUM(CASE WHEN payer_id_pro IS NULL THEN 1 ELSE 0 END) AS null_payer_id_pro,
    SUM(CASE WHEN payer_id_elig IS NULL THEN 1 ELSE 0 END) AS null_payer_id_elig,
    COUNT(*) AS total_records;

-- ----------------------------------------------------------------------------
-- CHECK 4: Predict Match Outcomes (Dry Run)
-- ----------------------------------------------------------------------------
WITH match_prediction AS (
    SELECT
        ifirm.firm_id,
        ifirm.payer_id,
        ifirm.name,
        if_oa.payer_id AS oa_payer_id,
        if_oa.name AS oa_name,
        CASE
            WHEN IFNULL(ifirm.payer_id, '') = IFNULL(if_oa.payer_id, '')
             AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
                THEN 'EXACT_MATCH'
            WHEN IFNULL(ifirm.payer_id, '') = IFNULL(if_oa.payer_id, '')
                THEN 'PAYER_ID_ONLY'
            WHEN IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
                THEN 'NAME_ONLY'
            ELSE 'NO_MATCH'
        END AS predicted_match_status
    FROM insurance_firm ifirm
    LEFT JOIN insurance_firm_oa if_oa
        ON ifirm.payer_id = if_oa.payer_id
        OR LOWER(ifirm.name) = LOWER(if_oa.name
)
)
SELECT
    predicted_match_status,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM match_prediction
GROUP BY predicted_match_status
ORDER BY
    CASE predicted_match_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        WHEN 'NO_MATCH' THEN 4
        ELSE 5
    END;

-- ----------------------------------------------------------------------------
-- CHECK 5: Identify Potential Issues
-- ----------------------------------------------------------------------------

-- Issue 1: Duplicate payer_ids in insurance_firm_oa
SELECT
    'DUPLICATE PAYER_IDS IN OA' AS issue_type,
    payer_id,
    COUNT(*) AS duplicate_count,
    STRING_AGG(DISTINCT name, ', ') AS different_names
FROM insurance_firm_oa
WHERE payer_id IS NOT NULL
GROUP BY payer_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 10;

-- Issue 2: Duplicate names in insurance_firm_oa
SELECT
    'DUPLICATE NAMES IN OA' AS issue_type,
    name,
    COUNT(*) AS duplicate_count,
    STRING_AGG(DISTINCT payer_id, ', ') AS different_payer_ids
FROM insurance_firm_oa
WHERE name IS NOT NULL
GROUP BY name
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 10;

-- Issue 3: Names with extra spaces (common data quality issue)
SELECT
    'NAMES WITH EXTRA SPACES' AS issue_type,
    firm_id,
    payer_id,
    '"' || name || '"' AS name_with_spaces,
    LENGTH(name) - LENGTH(REPLACE(name, ' ', '')) AS space_count
FROM insurance_firm
WHERE name LIKE '%  %'  -- Double spaces
   OR name LIKE ' %'    -- Leading space
   OR name LIKE '% '    -- Trailing space
LIMIT 10;

-- Issue 4: Check if insurance_firm_oa has all expected columns
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'insurance_firm_oa'
  AND TABLE_SCHEMA = DATABASE()
ORDER BY ORDINAL_POSITION;

-- ----------------------------------------------------------------------------
-- CHECK 6: Sample Data Comparison
-- ----------------------------------------------------------------------------
SELECT
    'SAMPLE MATCH PREVIEW' AS preview_type,
    ifirm.firm_id,
    ifirm.payer_id AS firm_payer_id,
    ifirm.name AS firm_name,
    if_oa.payer_id AS oa_payer_id,
    if_oa.name AS oa_name,
    CASE
        WHEN IFNULL(ifirm.payer_id, '') = IFNULL(if_oa.payer_id, '')
         AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
            THEN '✓ EXACT'
        WHEN IFNULL(ifirm.payer_id, '') = IFNULL(if_oa.payer_id, '')
            THEN '⚠ PAYER_ID_ONLY'
        WHEN IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
            THEN '⚠ NAME_ONLY'
        ELSE '✗ NO_MATCH'
    END AS match_type
FROM insurance_firm ifirm
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
LIMIT 20;

-- ----------------------------------------------------------------------------
-- CHECK 7: Patient Insurance Impact Assessment
-- ----------------------------------------------------------------------------
SELECT
    'PATIENT INSURANCE IMPACT' AS check_type,
    COUNT(DISTINCT pi.insurance_firm_id) AS unique_firms_referenced,
    COUNT(*) AS total_patient_insurance_records,
    (SELECT COUNT(*) FROM insurance_firm) AS total_firms,
    (SELECT COUNT(*) FROM insurance_firm WHERE payer_id IS NULL) AS firms_with_null_payer_id
FROM patient_insurance pi;

-- Find patient_insurance records that reference firms with NULL payer_id
SELECT
    'PATIENT RECORDS WITH NULL PAYER_ID' AS check_type,
    COUNT(*) AS affected_patients
FROM patient_insurance pi
JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
WHERE ifirm.payer_id IS NULL;

-- ----------------------------------------------------------------------------
-- CHECK 8: Index Check
-- ----------------------------------------------------------------------------
SELECT
    'INDEX CHECK' AS check_type,
    TABLE_NAME,
    INDEX_NAME,
    COLUMN_NAME,
    SEQ_IN_INDEX
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_NAME IN ('insurance_firm', 'insurance_firm_oa')
  AND COLUMN_NAME IN ('payer_id', 'name')
  AND TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

-- ----------------------------------------------------------------------------
-- RECOMMENDATIONS
-- ----------------------------------------------------------------------------
SELECT
    'RECOMMENDATIONS' AS info,
    '1. Review match prediction above - if EXACT_MATCH < 80%, investigate data quality issues' AS step1,
    '2. Fix duplicate names/payer_ids in insurance_firm_oa before syncing' AS step2,
    '3. Trim spaces from names: UPDATE insurance_firm SET name = TRIM(name)' AS step3,
    '4. Create indexes if not present for better performance' AS step4,
    '5. Backup data before running sync script' AS step5;
