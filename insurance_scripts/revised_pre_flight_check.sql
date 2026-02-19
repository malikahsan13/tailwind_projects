-- ============================================================================
-- PRE-FLIGHT CHECK - REVISED VERSION
-- ============================================================================
-- Run BEFORE executing sync script to understand your data
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
-- CHECK 2: Check if new columns exist
-- ----------------------------------------------------------------------------
SELECT
    'COLUMN CHECK' AS check_type,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'insurance_firm'
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME IN (
      'payer_id_new',
      'name_new',
      'payer_id_fac',
      'payer_id_pro',
      'payer_id_elig'
  )
ORDER BY COLUMN_NAME;

-- If payer_id_new and name_new don't exist, you need to add them:
-- ALTER TABLE insurance_firm
-- ADD COLUMN payer_id_new VARCHAR(200) NULL AFTER payer_id,
-- ADD COLUMN name_new VARCHAR(255) NULL AFTER payer_id_new;

-- ----------------------------------------------------------------------------
-- CHECK 3: Predict Match Outcomes (Dry Run)
-- ----------------------------------------------------------------------------
WITH match_prediction AS (
    SELECT
        ifirm.firm_id,
        ifirm.payer_id AS old_payer_id,
        ifirm.name AS old_name,
        if_oa.payer_id AS new_payer_id,
        if_oa.name AS new_name,
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
        OR LOWER(ifirm.name) = LOWER(if_oa.name)
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
-- CHECK 4: Identify Records to be Deleted (Garbage)
-- ----------------------------------------------------------------------------
-- These are in insurance_firm but NOT in insurance_firm_oa
SELECT
    'RECORDS TO DELETE (GARBAGE)' AS info,
    COUNT(*) AS count
FROM insurance_firm ifirm
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id IS NULL;

-- Show sample of records that will be deleted
SELECT
    'SAMPLE GARBAGE RECORDS' AS info,
    firm_id,
    payer_id,
    name
FROM insurance_firm ifirm
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id IS NULL
LIMIT 10;

-- ----------------------------------------------------------------------------
-- CHECK 5: Check if these garbage records are used in patient_insurance
-- ----------------------------------------------------------------------------
SELECT
    'PATIENT INSURANCE IMPACT' AS check_type,
    COUNT(DISTINCT ifirm.firm_id) AS garbage_firm_count,
    COUNT(*) AS affected_patient_records,
    'These patients will be affected by deletion!' AS warning
FROM insurance_firm ifirm
JOIN patient_insurance pi ON ifirm.firm_id = pi.insurance_firm_id
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id IS NULL;

-- Show which patient records are affected
SELECT
    'AFFECTED PATIENT RECORDS SAMPLE' AS info,
    pi.patient_insurance_id,
    ifirm.firm_id,
    ifirm.payer_id,
    ifirm.name
FROM patient_insurance pi
JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id IS NULL
LIMIT 20;

-- ----------------------------------------------------------------------------
-- CHECK 6: Identify Records to be Inserted (New from OA)
-- ----------------------------------------------------------------------------
-- These are in insurance_firm_oa but NOT in insurance_firm
SELECT
    'RECORDS TO INSERT (NEW FROM OA)' AS info,
    COUNT(*) AS count
FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL;

-- Show sample of records that will be inserted
SELECT
    'SAMPLE NEW RECORDS FROM OA' AS info,
    payer_id,
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig
FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL
LIMIT 10;

-- ----------------------------------------------------------------------------
-- CHECK 7: Sample Data Comparison
-- ----------------------------------------------------------------------------
SELECT
    'SAMPLE MATCH PREVIEW' AS preview_type,
    ifirm.firm_id,
    ifirm.payer_id AS old_payer_id,
    ifirm.name AS old_name,
    if_oa.payer_id AS new_payer_id,
    if_oa.name AS new_name,
    CASE
        WHEN IFNULL(ifirm.payer_id, '') = IFNULL(if_oa.payer_id, '')
         AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
            THEN '✓ EXACT (will update)'
        WHEN IFNULL(ifirm.payer_id, '') = IFNULL(if_oa.payer_id, '')
            THEN '⚠ PAYER_ID_ONLY (will update)'
        WHEN IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
            THEN '⚠ NAME_ONLY (will update)'
        ELSE '✗ NO_MATCH (will delete & reinsert)'
    END AS action
FROM insurance_firm ifirm
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
LIMIT 20;

-- ----------------------------------------------------------------------------
-- SUMMARY & RECOMMENDATIONS
-- ----------------------------------------------------------------------------
SELECT
    'SUMMARY' AS info,
    '1. Review garbage records that will be deleted' AS step1,
    '2. Check if patient_insurance will be affected by deletions' AS step2,
    '3. If patient records affected, decide: reassign or cascade delete' AS step3,
    '4. Review new records from OA that will be inserted' AS step4,
    '5. Add payer_id_new and name_new columns if not present' AS step5;
