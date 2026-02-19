-- ============================================================================
-- PRE-FLIGHT CHECK - REVISED V2
-- ============================================================================
-- For when insurance_firm_oa.payer_id is NULL but fac/pro/elig are populated
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
-- CHECK 2: Verify insurance_firm_oa structure (payer_id is NULL)
-- ----------------------------------------------------------------------------
SELECT
    'OA DATA QUALITY CHECK' AS check_type,
    SUM(CASE WHEN payer_id IS NULL THEN 1 ELSE 0 END) AS null_payer_id,
    SUM(CASE WHEN payer_id IS NOT NULL THEN 1 ELSE 0 END) AS has_payer_id,
    SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) AS has_fac,
    SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) AS has_pro,
    SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) AS has_elig,
    COUNT(*) AS total_records
FROM insurance_firm_oa;

-- Sample of insurance_firm_oa data
SELECT
    'SAMPLE OA DATA' AS sample,
    payer_id,
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig
FROM insurance_firm_oa
LIMIT 10;

-- ----------------------------------------------------------------------------
-- CHECK 3: Predict Match Outcomes (Dry Run)
-- ----------------------------------------------------------------------------

-- Match logic: insurance_firm.payer_id matches any of OA's fac/pro/elig
WITH match_prediction AS (
    SELECT
        ifirm.firm_id,
        ifirm.payer_id AS old_payer_id,
        ifirm.name AS old_name,

        -- Try to match with OA on any of the three payer IDs
        if_oa.payer_id_fac,
        if_oa.payer_id_pro,
        if_oa.payer_id_elig,
        if_oa.name AS new_name,

        -- Determine match type
        CASE
            -- Exact match: payer_id matches fac/pro/elig AND name matches
            WHEN (
                ifirm.payer_id = if_oa.payer_id_fac
                OR ifirm.payer_id = if_oa.payer_id_pro
                OR ifirm.payer_id = if_oa.payer_id_elig
            )
            AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
                THEN 'EXACT_MATCH'

            -- Payer ID only: matches fac/pro/elig but name differs
            WHEN (
                ifirm.payer_id = if_oa.payer_id_fac
                OR ifirm.payer_id = if_oa.payer_id_pro
                OR ifirm.payer_id = if_oa.payer_id_elig
            )
            AND IFNULL(LOWER(ifirm.name), '') != IFNULL(LOWER(if_oa.name), '')
                THEN 'PAYER_ID_ONLY'

            -- Name only: name matches but payer_id doesn't match any
            WHEN IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
            AND ifirm.payer_id != if_oa.payer_id_fac
            AND ifirm.payer_id != if_oa.payer_id_pro
            AND ifirm.payer_id != if_oa.payer_id_elig
                THEN 'NAME_ONLY'

            -- No match
            ELSE 'NO_MATCH'
        END AS predicted_match_status,

        -- Track which payer ID matched
        CASE
            WHEN ifirm.payer_id = if_oa.payer_id_fac THEN 'fac'
            WHEN ifirm.payer_id = if_oa.payer_id_pro THEN 'pro'
            WHEN ifirm.payer_id = if_oa.payer_id_elig THEN 'elig'
            ELSE NULL
        END AS matched_via

    FROM insurance_firm ifirm
    LEFT JOIN insurance_firm_oa if_oa
        ON ifirm.payer_id = if_oa.payer_id_fac
        OR ifirm.payer_id = if_oa.payer_id_pro
        OR ifirm.payer_id = if_oa.payer_id_elig
        OR LOWER(ifirm.name) = LOWER(if_oa.name)
)
SELECT
    predicted_match_status,
    matched_via,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM match_prediction
GROUP BY predicted_match_status, matched_via
ORDER BY
    CASE predicted_match_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        WHEN 'NO_MATCH' THEN 4
        ELSE 5
    END,
    matched_via;

-- ----------------------------------------------------------------------------
-- CHECK 4: Identify Records to be Deleted (Garbage)
-- ----------------------------------------------------------------------------
SELECT
    'RECORDS TO DELETE (GARBAGE)' AS info,
    COUNT(*) AS count
FROM insurance_firm ifirm
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id_fac IS NULL
  AND if_oa.payer_id_pro IS NULL
  AND if_oa.payer_id_elig IS NULL;

-- Show sample of records that will be deleted
SELECT
    'SAMPLE GARBAGE RECORDS' AS info,
    firm_id,
    payer_id,
    name
FROM insurance_firm ifirm
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id_fac IS NULL
  AND if_oa.payer_id_pro IS NULL
  AND if_oa.payer_id_elig IS NULL
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
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id_fac IS NULL
  AND if_oa.payer_id_pro IS NULL
  AND if_oa.payer_id_elig IS NULL;

-- ----------------------------------------------------------------------------
-- CHECK 6: Identify Records to be Inserted (New from OA)
-- ----------------------------------------------------------------------------
SELECT
    'RECORDS TO INSERT (NEW FROM OA)' AS info,
    COUNT(*) AS count
FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id_fac = ifirm.payer_id
    OR if_oa.payer_id_pro = ifirm.payer_id
    OR if_oa.payer_id_elig = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL;

-- Show sample of records that will be inserted
SELECT
    'SAMPLE NEW RECORDS FROM OA' AS info,
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig
FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id_fac = ifirm.payer_id
    OR if_oa.payer_id_pro = ifirm.payer_id
    OR if_oa.payer_id_elig = ifirm.payer_id
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
    if_oa.payer_id_fac,
    if_oa.payer_id_pro,
    if_oa.payer_id_elig,
    if_oa.name AS new_name,
    CASE
        WHEN (
            ifirm.payer_id = if_oa.payer_id_fac
            OR ifirm.payer_id = if_oa.payer_id_pro
            OR ifirm.payer_id = if_oa.payer_id_elig
        )
        AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
            THEN '✓ EXACT (will update)'
        WHEN (
            ifirm.payer_id = if_oa.payer_id_fac
            OR ifirm.payer_id = if_oa.payer_id_pro
            OR ifirm.payer_id = if_oa.payer_id_elig
        )
            THEN '⚠ PAYER_ID_ONLY (will update)'
        WHEN IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
            THEN '⚠ NAME_ONLY (will update)'
        ELSE '✗ NO_MATCH (will delete & reinsert)'
    END AS action
FROM insurance_firm ifirm
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
LIMIT 20;

-- ----------------------------------------------------------------------------
-- CHECK 8: Analyze payer_id_new determination logic
-- ----------------------------------------------------------------------------
SELECT
    'PAYER_ID_NEW DETERMINATION STRATEGY' AS strategy,
    'Since OA.payer_id is NULL, we need to decide which ID to use as payer_id_new' AS note,
    'Options:' AS options,
    '1. Use payer_id_fac if present' AS opt1,
    '2. Use payer_id_pro if fac is null' AS opt2,
    '3. Use payer_id_elig if both are null' AS opt3,
    '4. Leave NULL if all are null' AS opt4;

-- Show what payer_id_new would be for each OA record
SELECT
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig,
    COALESCE(payer_id_fac, payer_id_pro, payer_id_elig) AS suggested_payer_id_new,
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'Using fac'
        WHEN payer_id_pro IS NOT NULL THEN 'Using pro'
        WHEN payer_id_elig IS NOT NULL THEN 'Using elig'
        ELSE 'All NULL'
    END AS source
FROM insurance_firm_oa
LIMIT 20;

-- ----------------------------------------------------------------------------
-- SUMMARY & RECOMMENDATIONS
-- ----------------------------------------------------------------------------
SELECT
    'SUMMARY' AS info,
    '1. Review match prediction above' AS step1,
    '2. Decide on payer_id_new strategy (fac > pro > elig priority)' AS step2,
    '3. Check if patient_insurance will be affected by deletions' AS step3,
    '4. Review new records from OA that will be inserted' AS step4,
    '5. Run sync script with updated matching logic' AS step5;
