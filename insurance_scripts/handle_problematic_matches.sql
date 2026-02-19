-- ============================================================================
-- HANDLE PROBLEMATIC MATCHES
-- ============================================================================
-- Use these queries to manually resolve records that didn't match exactly
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SCENARIO 1: PAYER_ID_ONLY Matches
-- Problem: Payer ID matches but NAME differs
-- Question: Which name is correct?
-- ----------------------------------------------------------------------------

-- Review all PAYER_ID_ONLY matches
SELECT
    firm_id,
    payer_id AS payer_id,
    name AS current_name_in_firm,
    correct_name_from_oa AS correct_name_in_oa,
    match_details,
    -- Check which one looks better
    CASE
        WHEN LENGTH(name) < LENGTH(correct_name_from_oa) THEN 'OA name is longer/detailed'
        WHEN LENGTH(name) > LENGTH(correct_name_from_oa) THEN 'Firm name is longer/detailed'
        ELSE 'Both same length'
    END AS comparison
FROM insurance_firm
WHERE match_status = 'PAYER_ID_ONLY'
ORDER BY payer_id;

-- Option A: Update to insurance_firm_oa name (recommended - OA is source of truth)
UPDATE insurance_firm
SET
    name = correct_name_from_oa,
    payer_id = correct_name_from_oa,  -- Update payer_id if needed
    match_status = 'CORRECTED_PAYER_ID_ONLY',
    match_details = CONCAT('Updated name from "', name, '" to "', correct_name_from_oa, '" based on insurance_firm_oa'),
    last_synced_at = CURRENT_TIMESTAMP
WHERE match_status = 'PAYER_ID_ONLY';

-- Option B: Keep insurance_firm name and update insurance_firm_oa (if firm has better data)
-- Use this ONLY if you're sure insurance_firm has correct names
-- INSERT INTO insurance_firm_oa (name, ...) VALUES (...)

-- ----------------------------------------------------------------------------
-- SCENARIO 2: NAME_ONLY Matches
-- Problem: NAME matches but PAYER_ID differs
-- Question: Which payer_id is correct?
-- ----------------------------------------------------------------------------

-- Review all NAME_ONLY matches
SELECT
    firm_id,
    name AS payer_name,
    payer_id AS current_payer_id_in_firm,
    correct_name_from_oa,
    -- Need to see what the correct payer_id should be
    (SELECT payer_id FROM insurance_firm_oa WHERE LOWER(name) = LOWER(insurance_firm.name) LIMIT 1) AS correct_payer_id_in_oa,
    match_details
FROM insurance_firm
WHERE match_status = 'NAME_ONLY'
ORDER BY name;

-- Option A: Update to insurance_firm_oa payer_id (recommended)
UPDATE insurance_firm
SET
    payer_id = (SELECT if_oa.payer_id
                FROM insurance_firm_oa if_oa
                WHERE LOWER(if_oa.name) = LOWER(insurance_firm.name)
                LIMIT 1),
    match_status = 'CORRECTED_NAME_ONLY',
    match_details = CONCAT('Updated payer_id based on name match with insurance_firm_oa'),
    last_synced_at = CURRENT_TIMESTAMP
WHERE match_status = 'NAME_ONLY';

-- ----------------------------------------------------------------------------
-- SCENARIO 3: NO_MATCH Records
-- Problem: No matching record found in insurance_firm_oa
-- Solutions: Add to OA, mark as invalid, or leave for review
-- ----------------------------------------------------------------------------

-- Review all NO_MATCH records
SELECT
    firm_id,
    payer_id,
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig,
    -- Check if any of the sub-payer IDs exist in OA
    (SELECT COUNT(*) FROM insurance_firm_oa WHERE payer_id = insurance_firm.payer_id_fac) AS fac_id_in_oa,
    (SELECT COUNT(*) FROM insurance_firm_oa WHERE payer_id = insurance_firm.payer_id_pro) AS pro_id_in_oa,
    (SELECT COUNT(*) FROM insurance_firm_oa WHERE payer_id = insurance_firm.payer_id_elig) AS elig_id_in_oa
FROM insurance_firm
WHERE match_status = 'NO_MATCH'
ORDER BY name;

-- Option A: Try to match using sub-payer IDs
-- If any of the sub-payer IDs (fac/pro/elig) exist in OA, use those to match
UPDATE insurance_firm ifirm
SET
    payer_id = (
        SELECT if_oa.payer_id
        FROM insurance_firm_oa if_oa
        WHERE if_oa.payer_id IN (
            ifirm.payer_id_fac,
            ifirm.payer_id_pro,
            ifirm.payer_id_elig
        )
        LIMIT 1
    ),
    match_status = 'MATCHED_VIA_SUB_PAYER',
    match_details = 'Matched via facility/professional/eligibility payer_id',
    last_synced_at = CURRENT_TIMESTAMP
WHERE match_status = 'NO_MATCH'
  AND EXISTS (
      SELECT 1
      FROM insurance_firm_oa if_oa
      WHERE if_oa.payer_id IN (ifirm.payer_id_fac, ifirm.payer_id_pro, ifirm.payer_id_elig)
  );

-- Option B: Add missing payers to insurance_firm_oa
-- First, identify which ones to add
SELECT
    'READY TO ADD TO OA' AS action,
    firm_id,
    payer_id,
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig
FROM insurance_firm
WHERE match_status = 'NO_MATCH'
  AND payer_id IS NOT NULL
  AND name IS NOT NULL;

-- Then insert them (uncomment and review first)
/*
INSERT INTO insurance_firm_oa (
    payer_id, name,
    payer_id_fac, payer_id_fac_enrollment,
    payer_id_pro, payer_id_pro_enrollment,
    payer_id_elig, payer_id_elig_enrollment,
    non_par_fac, non_par_pro, non_par_elig,
    secondary_ins_fac, secondary_ins_pro, secondary_ins_elig,
    attachment_fac, attachment_pro, attachment_elig,
    wc_auto_fac, wc_auto_pro, wc_auto_elig
)
SELECT
    payer_id, name,
    payer_id_fac, payer_id_fac_enrollment,
    payer_id_pro, payer_id_pro_enrollment,
    payer_id_elig, payer_id_elig_enrollment,
    non_par_fac, non_par_pro, non_par_elig,
    secondary_ins_fac, secondary_ins_pro, secondary_ins_elig,
    attachment_fac, attachment_pro, attachment_elig,
    wc_auto_fac, wc_auto_pro, wc_auto_elig
FROM insurance_firm
WHERE match_status = 'NO_MATCH'
  AND payer_id IS NOT NULL
  AND name IS NOT NULL;
*/

-- Option C: Mark as inactive/invalid if they shouldn't exist
UPDATE insurance_firm
SET
    match_status = 'INVALID_PAYER',
    match_details = 'No matching record in insurance_firm_oa - marked for deletion',
    last_synced_at = CURRENT_TIMESTAMP
WHERE match_status = 'NO_MATCH'
  AND -- Add your criteria here, for example:
      (
          payer_id IS NULL
          OR name IS NULL
          OR name LIKE '%TEST%'
          OR name LIKE '%DEMO%'
      );

-- ----------------------------------------------------------------------------
-- FINAL VERIFICATION
-- ----------------------------------------------------------------------------

-- Check final match status distribution
SELECT
    match_status,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
GROUP BY match_status
ORDER BY count DESC;

-- Find any remaining issues
SELECT
    'REMAINING ISSUES' AS status,
    SUM(CASE WHEN match_status IN ('PAYER_ID_ONLY', 'NAME_ONLY', 'NO_MATCH') THEN 1 ELSE 0 END) AS needs_review,
    SUM(CASE WHEN match_status = 'EXACT_MATCH' THEN 1 ELSE 0 END) AS exact_match,
    SUM(CASE WHEN match_status LIKE 'CORRECTED%' THEN 1 ELSE 0 END) AS corrected,
    COUNT(*) AS total
FROM insurance_firm;
