-- ============================================================================
-- STEP 2.2: PREDICT MATCH OUTCOMES
-- ============================================================================
-- Purpose: Preview what will happen during sync without making changes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Predict match outcomes
-- ----------------------------------------------------------------------------
SELECT
    '=== MATCH PREDICTION SUMMARY ===' AS prediction,
    match_status,
    matched_via,
    COUNT(*) AS predicted_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM (
    SELECT
        ifirm.firm_id,
        CASE
            WHEN (
                ifirm.payer_id = if_oa.payer_id_fac
                OR ifirm.payer_id = if_oa.payer_id_pro
                OR ifirm.payer_id = if_oa.payer_id_elig
            )
            AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
                THEN 'EXACT_MATCH'
            WHEN (
                ifirm.payer_id = if_oa.payer_id_fac
                OR ifirm.payer_id = if_oa.payer_id_pro
                OR ifirm.payer_id = if_oa.payer_id_elig
            )
                THEN 'PAYER_ID_ONLY'
            WHEN IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
                THEN 'NAME_ONLY'
            ELSE 'NO_MATCH'
        END AS match_status,
        CASE
            WHEN ifirm.payer_id = if_oa.payer_id_fac THEN 'fac'
            WHEN ifirm.payer_id = if_oa.payer_id_pro THEN 'pro'
            WHEN ifirm.payer_id = if_oa.payer_id_elig THEN 'elig'
            WHEN IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '') THEN 'name'
            ELSE NULL
        END AS matched_via
    FROM insurance_firm ifirm
    LEFT JOIN insurance_firm_oa if_oa
        ON ifirm.payer_id = if_oa.payer_id_fac
        OR ifirm.payer_id = if_oa.payer_id_pro
        OR ifirm.payer_id = if_oa.payer_id_elig
        OR LOWER(ifirm.name) = LOWER(if_oa.name)
) predictions
GROUP BY match_status, matched_via
ORDER BY
    CASE match_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        WHEN 'NO_MATCH' THEN 4
        ELSE 5
    END,
    matched_via;

-- ----------------------------------------------------------------------------
-- Sample of exact matches (will be updated)
-- ----------------------------------------------------------------------------
SELECT
    '=== SAMPLE: EXACT MATCHES (Will Update) ===' AS sample_type,
    ifirm.firm_id,
    ifirm.payer_id AS old_payer_id,
    ifirm.name AS old_name,
    COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig) AS new_payer_id,
    if_oa.name AS new_name,
    CASE
        WHEN ifirm.payer_id = if_oa.payer_id_fac THEN 'fac'
        WHEN ifirm.payer_id = if_oa.payer_id_pro THEN 'pro'
        WHEN ifirm.payer_id = if_oa.payer_id_elig THEN 'elig'
        ELSE 'unknown'
    END AS matched_via,
    if_oa.payer_id_fac,
    if_oa.payer_id_pro,
    if_oa.payer_id_elig
FROM insurance_firm ifirm
INNER JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
WHERE (
    ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
)
AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Sample of PAYER_ID_ONLY matches (name differs)
-- ----------------------------------------------------------------------------
SELECT
    '=== SAMPLE: PAYER_ID_ONLY (Name Differs) ===' AS sample_type,
    ifirm.firm_id,
    ifirm.payer_id AS old_payer_id,
    ifirm.name AS old_name,
    COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig) AS new_payer_id,
    if_oa.name AS new_name,
    CONCAT('Old: "', ifirm.name, '" → New: "', if_oa.name, '"') AS issue,
    CASE
        WHEN ifirm.payer_id = if_oa.payer_id_fac THEN 'fac'
        WHEN ifirm.payer_id = if_oa.payer_id_pro THEN 'pro'
        WHEN ifirm.payer_id = if_oa.payer_id_elig THEN 'elig'
        ELSE 'unknown'
    END AS matched_via
FROM insurance_firm ifirm
INNER JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
WHERE (
    ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
)
AND IFNULL(LOWER(ifirm.name), '') != IFNULL(LOWER(if_oa.name), '')
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Sample of NAME_ONLY matches (payer_id differs)
-- ----------------------------------------------------------------------------
SELECT
    '=== SAMPLE: NAME_ONLY (Payer ID Differs) ===' AS sample_type,
    ifirm.firm_id,
    ifirm.payer_id AS old_payer_id,
    ifirm.name AS old_name,
    COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig) AS new_payer_id,
    if_oa.name AS new_name,
    CONCAT('Old ID: "', ifirm.payer_id, '" → New ID: "',
           COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig), '"') AS issue
FROM insurance_firm ifirm
INNER JOIN insurance_firm_oa if_oa
    ON LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
AND ifirm.payer_id != if_oa.payer_id_fac
AND ifirm.payer_id != if_oa.payer_id_pro
AND ifirm.payer_id != if_oa.payer_id_elig
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Sample of NO_MATCH records (will be deleted as garbage)
-- ----------------------------------------------------------------------------
SELECT
    '=== SAMPLE: NO_MATCH (Will Delete) ===' AS sample_type,
    ifirm.firm_id,
    ifirm.payer_id,
    ifirm.name,
    'Not found in insurance_firm_oa' AS reason
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
-- Predict records to be inserted from OA
-- ----------------------------------------------------------------------------
SELECT
    '=== RECORDS TO INSERT FROM OA ===' AS prediction,
    COUNT(*) AS predicted_insert_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm_oa), 2) AS percentage_of_oa
FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id_fac = ifirm.payer_id
    OR if_oa.payer_id_pro = ifirm.payer_id
    OR if_oa.payer_id_elig = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL;

-- Sample of records to insert
SELECT
    '=== SAMPLE: NEW RECORDS FROM OA (Will Insert) ===' AS sample_type,
    if_oa.name,
    if_oa.payer_id_fac,
    if_oa.payer_id_pro,
    if_oa.payer_id_elig,
    COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig) AS will_be_payer_id
FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id_fac = ifirm.payer_id
    OR if_oa.payer_id_pro = ifirm.payer_id
    OR if_oa.payer_id_elig = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL
LIMIT 10;

-- ----------------------------------------------------------------------------
-- payer_id_new determination preview
-- ----------------------------------------------------------------------------
SELECT
    '=== PAYER_ID_NEW SOURCE PREDICTION ===' AS prediction,
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'From fac'
        WHEN payer_id_pro IS NOT NULL THEN 'From pro'
        WHEN payer_id_elig IS NOT NULL THEN 'From elig'
        ELSE 'All NULL'
    END AS payer_id_new_source,
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
-- Overall prediction summary
-- ----------------------------------------------------------------------------
SELECT
    '=== PREDICTION SUMMARY ===' AS summary_title,
    'REVIEW CAREFULLY BEFORE PROCEEDING' AS warning,
    (SELECT COUNT(*) FROM insurance_firm) AS current_firm_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) AS oa_count,
    (
        SELECT COUNT(*)
        FROM insurance_firm ifirm
        LEFT JOIN insurance_firm_oa if_oa
            ON ifirm.payer_id = if_oa.payer_id_fac
            OR ifirm.payer_id = if_oa.payer_id_pro
            OR ifirm.payer_id = if_oa.payer_id_elig
            OR LOWER(ifirm.name) = LOWER(if_oa.name)
        WHERE if_oa.payer_id_fac IS NULL
          AND if_oa.payer_id_pro IS NULL
          AND if_oa.payer_id_elig IS NULL
    ) AS predicted_deletions,
    (
        SELECT COUNT(*)
        FROM insurance_firm_oa if_oa
        LEFT JOIN insurance_firm ifirm
            ON if_oa.payer_id_fac = ifirm.payer_id
            OR if_oa.payer_id_pro = ifirm.payer_id
            OR if_oa.payer_id_elig = ifirm.payer_id
            OR LOWER(if_oa.name) = LOWER(ifirm.name)
        WHERE ifirm.firm_id IS NULL
    ) AS predicted_insertions,
    (SELECT COUNT(*) FROM insurance_firm) -
    (
        SELECT COUNT(*)
        FROM insurance_firm ifirm
        LEFT JOIN insurance_firm_oa if_oa
            ON ifirm.payer_id = if_oa.payer_id_fac
            OR ifirm.payer_id = if_oa.payer_id_pro
            OR ifirm.payer_id = if_oa.payer_id_elig
            OR LOWER(ifirm.name) = LOWER(if_oa.name)
        WHERE if_oa.payer_id_fac IS NULL
          AND if_oa.payer_id_pro IS NULL
          AND if_oa.payer_id_elig IS NULL
    ) +
    (
        SELECT COUNT(*)
        FROM insurance_firm_oa if_oa
        LEFT JOIN insurance_firm ifirm
            ON if_oa.payer_id_fac = ifirm.payer_id
            OR if_oa.payer_id_pro = ifirm.payer_id
            OR if_oa.payer_id_elig = ifirm.payer_id
            OR LOWER(if_oa.name) = LOWER(ifirm.name)
        WHERE ifirm.firm_id IS NULL
    ) AS expected_final_count;
