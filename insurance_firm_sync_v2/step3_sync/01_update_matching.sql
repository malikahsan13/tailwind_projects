-- ============================================================================
-- STEP 3.1: UPDATE MATCHING RECORDS
-- ============================================================================
-- Purpose: Phase 1 - Update all records that match with OA
-- Matching: insurance_firm.payer_id matches OA's fac/pro/elig OR name matches
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Create temporary table for match analysis
-- ----------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS insurance_firm_sync_analysis;

CREATE TEMPORARY TABLE insurance_firm_sync_analysis AS
SELECT
    ifirm.firm_id,
    ifirm.payer_id AS old_payer_id,
    ifirm.name AS old_name,

    -- Determine which payer_id to use as "new" (priority: fac > pro > elig)
    COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig) AS new_payer_id,
    if_oa.name AS new_name,

    -- Determine match status
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

    -- Track which column matched
    CASE
        WHEN ifirm.payer_id = if_oa.payer_id_fac THEN 'fac'
        WHEN ifirm.payer_id = if_oa.payer_id_pro THEN 'pro'
        WHEN ifirm.payer_id = if_oa.payer_id_elig THEN 'elig'
        WHEN IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '') THEN 'name'
        ELSE NULL
    END AS matched_via,

    -- All data from insurance_firm_oa
    if_oa.payer_id_fac,
    if_oa.payer_id_fac_enrollment,
    if_oa.payer_id_pro,
    if_oa.payer_id_pro_enrollment,
    if_oa.payer_id_elig,
    if_oa.payer_id_elig_enrollment,
    if_oa.non_par_fac,
    if_oa.non_par_pro,
    if_oa.non_par_elig,
    if_oa.secondary_ins_fac,
    if_oa.secondary_ins_pro,
    if_oa.secondary_ins_elig,
    if_oa.attachment_fac,
    if_oa.attachment_pro,
    if_oa.attachment_elig,
    if_oa.wc_auto_fac,
    if_oa.wc_auto_pro,
    if_oa.wc_auto_elig

FROM insurance_firm ifirm
INNER JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name);

-- ----------------------------------------------------------------------------
-- Preview: Show match status distribution
-- ----------------------------------------------------------------------------
SELECT
    '=== PHASE 1: MATCH STATUS DISTRIBUTION ===' AS phase,
    match_status,
    matched_via,
    COUNT(*) AS record_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm_sync_analysis), 2) AS percentage
FROM insurance_firm_sync_analysis
GROUP BY match_status, matched_via
ORDER BY
    CASE match_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        ELSE 4
    END,
    matched_via;

-- ----------------------------------------------------------------------------
-- Preview: Sample of records to be updated
-- ----------------------------------------------------------------------------
SELECT
    '=== SAMPLE RECORDS TO UPDATE ===' AS sample,
    firm_id,
    old_payer_id,
    old_name,
    new_payer_id,
    new_name,
    match_status,
    matched_via
FROM insurance_firm_sync_analysis
ORDER BY
    CASE match_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        ELSE 4
    END
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Execute: Update insurance_firm with matched data
-- ----------------------------------------------------------------------------
UPDATE insurance_firm tgt
SET
    -- NEW columns for correct values (preserve old ones)
    payer_id_new = ma.new_payer_id,
    name_new = ma.new_name,
    matched_via = ma.matched_via,

    -- Update all payer IDs from OA
    payer_id_fac = ma.payer_id_fac,
    payer_id_fac_enrollment = ma.payer_id_fac_enrollment,
    payer_id_pro = ma.payer_id_pro,
    payer_id_pro_enrollment = ma.payer_id_pro_enrollment,
    payer_id_elig = ma.payer_id_elig,
    payer_id_elig_enrollment = ma.payer_id_elig_enrollment,

    -- Update all flags from OA
    non_par_fac = ma.non_par_fac,
    non_par_pro = ma.non_par_pro,
    non_par_elig = ma.non_par_elig,
    secondary_ins_fac = ma.secondary_ins_fac,
    secondary_ins_pro = ma.secondary_ins_pro,
    secondary_ins_elig = ma.secondary_ins_elig,
    attachment_fac = ma.attachment_fac,
    attachment_pro = ma.attachment_pro,
    attachment_elig = ma.attachment_elig,
    wc_auto_fac = ma.wc_auto_fac,
    wc_auto_pro = ma.wc_auto_pro,
    wc_auto_elig = ma.wc_auto_elig,

    -- Track sync status
    sync_status = ma.match_status,
    sync_details = CASE
        WHEN ma.match_status = 'EXACT_MATCH' THEN
            CONCAT('Perfect match. Matched via ', ma.matched_via, '. Old values preserved.')
        WHEN ma.match_status = 'PAYER_ID_ONLY' THEN
            CONCAT('Payer ID matches via ', ma.matched_via, '. Name differs - old: "', ma.old_name, '", new: "', ma.new_name, '"')
        WHEN ma.match_status = 'NAME_ONLY' THEN
            CONCAT('Name matches. Payer ID differs - old: "', ma.old_payer_id, '", new: "', ma.new_payer_id, '"')
        ELSE 'Unknown match status'
    END,
    last_synced_at = CURRENT_TIMESTAMP

FROM insurance_firm_sync_analysis ma
WHERE tgt.firm_id = ma.firm_id;

-- ----------------------------------------------------------------------------
-- Results: Show what was updated
-- ----------------------------------------------------------------------------
SELECT
    '=== PHASE 1 COMPLETE ===' AS status,
    COUNT(*) AS records_updated,
    'Matching records updated with OA data' AS description
FROM insurance_firm
WHERE sync_status IS NOT NULL
  AND last_synced_at >= NOW() - INTERVAL 1 MINUTE;

-- ----------------------------------------------------------------------------
-- Verification: Current sync status
-- ----------------------------------------------------------------------------
SELECT
    sync_status,
    matched_via,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm WHERE sync_status IS NOT NULL), 2) AS percentage
FROM insurance_firm
WHERE sync_status IS NOT NULL
GROUP BY sync_status, matched_via
ORDER BY
    CASE sync_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        ELSE 4
    END,
    matched_via;

-- ----------------------------------------------------------------------------
-- Sample of updated records
-- ----------------------------------------------------------------------------
SELECT
    firm_id,
    payer_id AS old_payer_id,
    name AS old_name,
    payer_id_new,
    name_new,
    matched_via,
    sync_status,
    sync_details,
    last_synced_at
FROM insurance_firm
WHERE sync_status IS NOT NULL
ORDER BY last_synced_at DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Clean up
-- ----------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS insurance_firm_sync_analysis;

-- ----------------------------------------------------------------------------
-- Next step message
-- ----------------------------------------------------------------------------
SELECT
    '✓ PHASE 1 COMPLETE' AS status,
    'All matching records have been updated' AS message,
    'Next: Run 02_delete_garbage.sql to remove garbage records' AS next_step;
