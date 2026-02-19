-- ============================================================================
-- CUSTOM CLEANUP EXECUTION - Patient and Claims Usage Based
-- ============================================================================
-- Purpose: Execute cleanup based on requirements validation
-- WARNING: This script will DELETE records - Review validation output first!
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PRE-EXECUTION SAFETY CHECK
-- ----------------------------------------------------------------------------

SELECT
    '=== PRE-EXECUTION SAFETY CHECK ===' AS safety_check;

-- Show what will be affected
SELECT
    'Firms with Claims' AS category,
    COUNT(DISTINCT insurance_firm_id) AS count,
    'Will be KEPT and UPDATED' AS action
FROM pms_claims
WHERE insurance_firm_id IS NOT NULL

UNION ALL

SELECT
    'Firms with Patients only',
    COUNT(DISTINCT insurance_firm_id),
    'Will be KEPT and UPDATED'
FROM patient_insurance
WHERE insurance_firm_id IS NOT NULL
  AND insurance_firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL)

UNION ALL

SELECT
    'Firms not used',
    COUNT(*),
    'Will be DELETED and RELOADED'
FROM insurance_firm
WHERE firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL);

-- ----------------------------------------------------------------------------
-- REQUIREMENT 1 & 2: UPDATE ACTIVE FIRMS WITH OA DATA
-- (Firms in claims OR firms in patient_insurance)
-- ----------------------------------------------------------------------------

SELECT
    '=== UPDATING ACTIVE FIRMS (Claims + Patient Insurance) ===' AS update_phase;

-- Create temp table for firms to keep
CREATE TEMPORARY TABLE IF NOT EXISTS temp_active_firms AS
SELECT DISTINCT
    ifirm.firm_id,
    ifirm.payer_id AS old_payer_id,
    ifirm.name AS old_name,
    COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig) AS new_payer_id,
    if_oa.name AS new_name,
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
        WHEN LOWER(ifirm.name) = LOWER(if_oa.name) THEN 'name'
        ELSE NULL
    END AS matched_via,
    if_oa.payer_id_fac,
    if_oa.payer_id_pro,
    if_oa.payer_id_elig,
    if_oa.payer_id_fac_enrollment,
    if_oa.payer_id_pro_enrollment,
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
    if_oa.wc_auto_elig,
    CASE
        WHEN ifirm.firm_id IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL) THEN 'In Claims'
        ELSE 'Patient Only'
    END AS firm_usage
FROM insurance_firm ifirm
INNER JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE ifirm.firm_id IN (
    SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL
);

-- Preview what will be updated
SELECT
    '=== UPDATE PREVIEW ===' AS preview,
    firm_usage,
    match_status,
    matched_via,
    COUNT(*) AS count
FROM temp_active_firms
GROUP BY firm_usage, match_status, matched_via
ORDER BY
    CASE firm_usage WHEN 'In Claims' THEN 1 ELSE 2 END,
    CASE match_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        ELSE 4
    END;

-- Execute update for active firms
UPDATE insurance_firm tgt
JOIN temp_active_firms af 
    ON tgt.firm_id = af.firm_id
SET
    tgt.payer_id_new = af.new_payer_id,
    tgt.name_new = af.new_name,
    tgt.matched_via = af.matched_via,
    tgt.payer_id_fac = af.payer_id_fac,
    tgt.payer_id_fac_enrollment = af.payer_id_fac_enrollment,
    tgt.payer_id_pro = af.payer_id_pro,
    tgt.payer_id_pro_enrollment = af.payer_id_pro_enrollment,
    tgt.payer_id_elig = af.payer_id_elig,
    tgt.payer_id_elig_enrollment = af.payer_id_elig_enrollment,
    tgt.non_par_fac = af.non_par_fac,
    tgt.non_par_pro = af.non_par_pro,
    tgt.non_par_elig = af.non_par_elig,
    tgt.secondary_ins_fac = af.secondary_ins_fac,
    tgt.secondary_ins_pro = af.secondary_ins_pro,
    tgt.secondary_ins_elig = af.secondary_ins_elig,
    tgt.attachment_fac = af.attachment_fac,
    tgt.attachment_pro = af.attachment_pro,
    tgt.attachment_elig = af.attachment_elig,
    tgt.wc_auto_fac = af.wc_auto_fac,
    tgt.wc_auto_pro = af.wc_auto_pro,
    tgt.wc_auto_elig = af.wc_auto_elig,
    tgt.sync_status = CONCAT('ACTIVE_', af.match_status),
    tgt.sync_details = CONCAT(
        'Updated with OA data. Usage: ', 
        af.firm_usage,
        '. Matched via: ', 
        af.matched_via
    ),
    tgt.last_synced_at = CURRENT_TIMESTAMP;

SELECT
    '=== ACTIVE FIRMS UPDATED ===' AS result,
    ROW_COUNT() AS records_updated,
    'Firms with claims and patients have been updated with OA data' AS description;

DROP TEMPORARY TABLE IF EXISTS temp_active_firms;

-- ----------------------------------------------------------------------------
-- REQUIREMENT 3: DELETE UNUSED FIRMS AND RELOAD FROM OA
-- (Firms NOT in patient_insurance)
-- ----------------------------------------------------------------------------

SELECT
    '=== DELETING UNUSED FIRMS ===' AS delete_phase;

-- Show what will be deleted
SELECT
    COUNT(*) AS firms_to_delete,
    'Firms not assigned to any patient' AS description
FROM insurance_firm
WHERE firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL);

-- Show sample before deletion
SELECT
    firm_id,
    payer_id,
    `name`,
    sync_status
FROM insurance_firm
WHERE firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL)
LIMIT 20;

-- Delete unused firms
DELETE FROM insurance_firm
WHERE firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL);

SELECT
    '=== UNUSED FIRMS DELETED ===' AS result,
    ROW_COUNT() AS records_deleted,
    'Firms not used by any patient have been removed' AS description;

-- ----------------------------------------------------------------------------
-- RELOAD: Insert missing records from OA
-- ----------------------------------------------------------------------------

SELECT
    '=== RELOADING FROM OA ===' AS reload_phase;

-- Check what needs to be inserted
SELECT
    COUNT(*) AS records_to_insert,
    'Records from OA not in insurance_firm' AS description
FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id_fac = ifirm.payer_id
    OR if_oa.payer_id_pro = ifirm.payer_id
    OR if_oa.payer_id_elig = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL;

-- Insert missing records from OA
INSERT INTO insurance_firm (
    payer_id,
    name,
    payer_id_new,
    name_new,
    matched_via,
    payer_id_fac,
    payer_id_fac_enrollment,
    payer_id_pro,
    payer_id_pro_enrollment,
    payer_id_elig,
    payer_id_elig_enrollment,
    non_par_fac,
    non_par_pro,
    non_par_elig,
    secondary_ins_fac,
    secondary_ins_pro,
    secondary_ins_elig,
    attachment_fac,
    attachment_pro,
    attachment_elig,
    wc_auto_fac,
    wc_auto_pro,
    wc_auto_elig,
    sync_status,
    sync_details,
    last_synced_at
)
SELECT
    COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig) AS payer_id,
    if_oa.name,
    COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig) AS payer_id_new,
    if_oa.name AS name_new,
    CASE
        WHEN if_oa.payer_id_fac IS NOT NULL THEN 'fac'
        WHEN if_oa.payer_id_pro IS NOT NULL THEN 'pro'
        WHEN if_oa.payer_id_elig IS NOT NULL THEN 'elig'
        ELSE NULL
    END AS matched_via,
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
    if_oa.wc_auto_elig,
    'RELOADED_FROM_OA' AS sync_status,
    'Reloaded from OA after cleanup' AS sync_details,
    CURRENT_TIMESTAMP AS last_synced_at
FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id_fac = ifirm.payer_id
    OR if_oa.payer_id_pro = ifirm.payer_id
    OR if_oa.payer_id_elig = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL;

SELECT
    '=== RELOADED FROM OA ===' AS result,
    ROW_COUNT() AS records_inserted,
    'Missing records from OA have been inserted' AS description;

-- ----------------------------------------------------------------------------
-- FINAL VERIFICATION
-- ----------------------------------------------------------------------------

SELECT
    '=== FINAL VERIFICATION ===' AS verification;

-- Row counts
SELECT
    (SELECT COUNT(*) FROM insurance_firm) AS insurance_firm_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) AS oa_count,
    ABS((SELECT COUNT(*) FROM insurance_firm) - (SELECT COUNT(*) FROM insurance_firm_oa)) AS difference;

-- Active firms status
SELECT
    'Active Firms (Claims + Patient Insurance) Status' AS status_check,
    CASE
        WHEN sync_status LIKE 'ACTIVE_%' THEN SUBSTRING(sync_status, 8)
        ELSE sync_status
    END AS sync_status,
    matched_via,
    COUNT(*) AS count
FROM insurance_firm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL)
GROUP BY
    CASE
        WHEN sync_status LIKE 'ACTIVE_%' THEN SUBSTRING(sync_status, 8)
        ELSE sync_status
    END,
    matched_via
ORDER BY count DESC;

-- Verify patient references intact
SELECT
    'Patient Insurance Integrity Check' AS integrity_check,
    COUNT(*) AS total_patient_records,
    SUM(CASE WHEN ifirm.firm_id IS NULL THEN 1 ELSE 0 END) AS orphaned_records,
    ROUND(SUM(CASE WHEN ifirm.firm_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS integrity_percentage
FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id;

-- Verify claims references intact
SELECT
    'Claims Integrity Check' AS integrity_check,
    COUNT(*) AS total_claims,
    SUM(CASE WHEN ifirm.firm_id IS NULL THEN 1 ELSE 0 END) AS orphaned_claims,
    ROUND(SUM(CASE WHEN ifirm.firm_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS integrity_percentage
FROM pms_claims pc
LEFT JOIN insurance_firm ifirm ON pc.insurance_firm_id = ifirm.firm_id
WHERE pc.insurance_firm_id IS NOT NULL;

-- Overall summary
SELECT
    '=== CLEANUP COMPLETE ===' AS summary,
    (SELECT COUNT(*) FROM insurance_firm WHERE sync_status LIKE 'ACTIVE_%') AS active_firms_updated,
    (SELECT COUNT(*) FROM insurance_firm WHERE sync_status = 'RELOADED_FROM_OA') AS firms_reloaded,
    (SELECT COUNT(*) FROM patient_insurance pi LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id WHERE ifirm.firm_id IS NULL) AS orphaned_patients,
    (SELECT COUNT(*) FROM pms_claims pc LEFT JOIN insurance_firm ifirm ON pc.insurance_firm_id = ifirm.firm_id WHERE pc.insurance_firm_id IS NOT NULL AND ifirm.firm_id IS NULL) AS orphaned_claims,
    CASE
        WHEN (SELECT COUNT(*) FROM patient_insurance pi LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id WHERE ifirm.firm_id IS NULL) = 0
         AND (SELECT COUNT(*) FROM pms_claims pc LEFT JOIN insurance_firm ifirm ON pc.insurance_firm_id = ifirm.firm_id WHERE pc.insurance_firm_id IS NOT NULL AND ifirm.firm_id IS NULL) = 0
        THEN '✓ SUCCESS: No orphaned records'
        ELSE '⚠️ WARNING: Some orphaned records exist'
    END AS status;
