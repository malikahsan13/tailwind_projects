-- ============================================================================
-- MATCH LOGIC REFERENCE
-- ============================================================================

-- The solution uses the following matching priority:

-- 1. EXACT_MATCH
--    - Both payer_id AND name match (case-insensitive)
--    - Action: Safe to auto-update

-- 2. PAYER_ID_ONLY
--    - payer_id matches BUT name differs
--    - Action: Manual review needed (which name is correct?)

-- 3. NAME_ONLY
--    - Name matches BUT payer_id differs
--    - Action: Manual review needed (which payer_id is correct?)

-- 4. NO_MATCH
--    - Neither payer_id nor name matches
--    - Action: Requires investigation or new payer creation

-- ============================================================================
-- TEST QUERIES - Run these before executing the full solution
-- ============================================================================

-- Preview what matches will look like:
SELECT
    ifirm.firm_id,
    ifirm.payer_id AS current_payer_id,
    ifirm.name AS current_name,

    -- Matching logic preview
    pp_oa.payer_id AS payers_oa_id,
    pp_oa.name AS payers_oa_name,

    CASE
        WHEN ifirm.payer_id = pp_oa.payer_id AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(pp_oa.name), '')
            THEN 'EXACT_MATCH'
        WHEN ifirm.payer_id = pp_oa.payer_id
            THEN 'PAYER_ID_ONLY'
        WHEN LOWER(ifirm.name) = LOWER(pp_oa.name)
            THEN 'NAME_ONLY'
        ELSE 'NO_MATCH'
    END AS expected_match_status

FROM insurance_firm ifirm
LEFT JOIN payers_oa pp_oa
    ON ifirm.payer_id = pp_oa.payer_id
    OR LOWER(ifirm.name) = LOWER(pp_oa.name)
LIMIT 20;

-- Check for duplicates in payers_oa:
SELECT
    payer_id,
    name,
    COUNT(*) AS row_count,
    STRING_AGG(DISTINCT transaction, ', ') AS transaction_types
FROM payers_oa
GROUP BY payer_id, name
HAVING COUNT(*) != 3
ORDER BY row_count DESC;

-- Find potential name variations (fuzzy match):
SELECT
    ifirm.firm_id,
    ifirm.name AS insurance_firm_name,
    pp_oa.name AS payers_oa_name,
    ifirm.payer_id AS insurance_firm_payer_id,
    pp_oa.payer_id AS payers_oa_payer_id,
    -- Similarity score (PostgreSQL)
    SIMILARITY(ifirm.name, pp_oa.name) AS name_similarity
FROM insurance_firm ifirm
CROSS JOIN payers_oa pp_oa
WHERE SIMILARITY(ifirm.name, pp_oa.name) > 0.6
  AND SIMILARITY(ifirm.name, pp_oa.name) < 1.0
ORDER BY name_similarity DESC
LIMIT 20;
