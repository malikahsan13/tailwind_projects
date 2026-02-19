-- ============================================================================
-- POST-SYNC CLEANUP V2 - For OA with NULL payer_id but populated fac/pro/elig
-- ============================================================================

-- ============================================================================
-- SECTION 1: HANDLE ORPHANED PATIENT_INSURANCE RECORDS
-- ============================================================================

-- Find all orphaned patient_insurance records
SELECT
    'ORPHANED PATIENT INSURANCE RECORDS' AS issue,
    pi.patient_insurance_id,
    pi.insurance_firm_id AS old_firm_id,
    'This firm no longer exists' AS reason
FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
WHERE ifirm.firm_id IS NULL;

-- Option A: Reassign to matching firm based on old payer_id
UPDATE patient_insurance pi
SET insurance_firm_id = (
    SELECT firm_id
    FROM insurance_firm ifirm
    WHERE ifirm.payer_id_new = (
        SELECT payer_id FROM insurance_firm WHERE firm_id = pi.insurance_firm_id
    )
    OR ifirm.payer_id_fac = (
        SELECT payer_id FROM insurance_firm WHERE firm_id = pi.insurance_firm_id
    )
    OR ifirm.payer_id_pro = (
        SELECT payer_id FROM insurance_firm WHERE firm_id = pi.insurance_firm_id
    )
    OR ifirm.payer_id_elig = (
        SELECT payer_id FROM insurance_firm WHERE firm_id = pi.insurance_firm_id
    )
    OR LOWER(ifirm.name_new) = LOWER(
        SELECT name FROM insurance_firm WHERE firm_id = pi.insurance_firm_id
    )
    LIMIT 1
)
WHERE NOT EXISTS (
    SELECT 1 FROM insurance_firm ifirm WHERE ifirm.firm_id = pi.insurance_firm_id
);

-- ============================================================================
-- SECTION 2: CLEANUP NAME AND PAYER_ID MISMATCHES
-- ============================================================================

-- Find records where old and new payer_id/name differ
SELECT
    'MISMATCHED RECORDS' AS issue,
    firm_id,
    payer_id AS old_payer_id,
    payer_id_new AS new_payer_id,
    name AS old_name,
    name_new AS new_name,
    matched_via,
    sync_status,
    CASE
        WHEN payer_id != payer_id_new AND name != name_new THEN 'Both differ'
        WHEN payer_id != payer_id_new THEN 'Only payer_id differs'
        WHEN name != name_new THEN 'Only name differs'
        ELSE 'Match'
    END AS mismatch_type,
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'fac exists'
        WHEN payer_id_pro IS NOT NULL THEN 'pro exists'
        WHEN payer_id_elig IS NOT NULL THEN 'elig exists'
        ELSE 'All NULL'
    END AS data_availability
FROM insurance_firm
WHERE (payer_id != payer_id_new OR name != name_new)
  AND sync_status IN ('PAYER_ID_ONLY', 'NAME_ONLY')
ORDER BY mismatch_type, name;

-- ============================================================================
-- SECTION 3: SYNC REMAINING NULL VALUES
-- ============================================================================

-- Find records with NULL values in critical fields
SELECT
    firm_id,
    payer_id,
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig,
    sync_status,
    matched_via,
    CASE
        WHEN payer_id_fac IS NULL AND payer_id_pro IS NULL AND payer_id_elig IS NULL THEN
            'All payer IDs are NULL'
        WHEN payer_id_fac IS NULL THEN 'Missing facility payer_id'
        WHEN payer_id_pro IS NULL THEN 'Missing professional payer_id'
        WHEN payer_id_elig IS NULL THEN 'Missing eligibility payer_id'
        ELSE 'Some missing'
    END AS issue
FROM insurance_firm
WHERE payer_id_fac IS NULL
   OR payer_id_pro IS NULL
   OR payer_id_elig IS NULL
ORDER BY name;

-- Try to match these remaining records with OA
UPDATE insurance_firm tgt
SET
    payer_id_new = COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig),
    name_new = if_oa.name,
    matched_via = CASE
        WHEN tgt.payer_id = if_oa.payer_id_fac THEN 'fac'
        WHEN tgt.payer_id = if_oa.payer_id_pro THEN 'pro'
        WHEN tgt.payer_id = if_oa.payer_id_elig THEN 'elig'
        WHEN LOWER(tgt.name) = LOWER(if_oa.name) THEN 'name'
        ELSE NULL
    END,
    payer_id_fac = if_oa.payer_id_fac,
    payer_id_fac_enrollment = if_oa.payer_id_fac_enrollment,
    payer_id_pro = if_oa.payer_id_pro,
    payer_id_pro_enrollment = if_oa.payer_id_pro_enrollment,
    payer_id_elig = if_oa.payer_id_elig,
    payer_id_elig_enrollment = if_oa.payer_id_elig_enrollment,
    non_par_fac = if_oa.non_par_fac,
    non_par_pro = if_oa.non_par_pro,
    non_par_elig = if_oa.non_par_elig,
    secondary_ins_fac = if_oa.secondary_ins_fac,
    secondary_ins_pro = if_oa.secondary_ins_pro,
    secondary_ins_elig = if_oa.secondary_ins_elig,
    attachment_fac = if_oa.attachment_fac,
    attachment_pro = if_oa.attachment_pro,
    attachment_elig = if_oa.attachment_elig,
    wc_auto_fac = if_oa.wc_auto_fac,
    wc_auto_pro = if_oa.wc_auto_pro,
    wc_auto_elig = if_oa.wc_auto_elig,
    sync_status = 'SYNCED_LATE',
    sync_details = CONCAT('Synced in cleanup phase via ',
                          CASE
                              WHEN tgt.payer_id = if_oa.payer_id_fac THEN 'fac'
                              WHEN tgt.payer_id = if_oa.payer_id_pro THEN 'pro'
                              WHEN tgt.payer_id = if_oa.payer_id_elig THEN 'elig'
                              WHEN LOWER(tgt.name) = LOWER(if_oa.name) THEN 'name'
                              ELSE 'unknown'
                          END),
    last_synced_at = CURRENT_TIMESTAMP
FROM insurance_firm_oa if_oa
WHERE tgt.payer_id = if_oa.payer_id_fac
   OR tgt.payer_id = if_oa.payer_id_pro
   OR tgt.payer_id = if_oa.payer_id_elig
   OR LOWER(tgt.name_new) = LOWER(if_oa.name)
   OR LOWER(tgt.name) = LOWER(if_oa.name);

-- ============================================================================
-- SECTION 4: FINAL VERIFICATION
-- ============================================================================

-- Overall sync status
SELECT
    '=== FINAL SYNC SUMMARY ===' AS summary,
    sync_status,
    matched_via,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
GROUP BY sync_status, matched_via
ORDER BY count DESC;

-- Data completeness check
SELECT
    '=== DATA COMPLETENESS ===' AS summary,
    SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) AS has_fac_id,
    SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) AS has_pro_id,
    SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) AS has_elig_id,
    SUM(CASE WHEN payer_id_new IS NOT NULL THEN 1 ELSE 0 END) AS has_new_payer_id,
    SUM(CASE WHEN name_new IS NOT NULL THEN 1 ELSE 0 END) AS has_new_name,
    COUNT(*) AS total_records
FROM insurance_firm;

-- Patient insurance integrity
SELECT
    '=== PATIENT INSURANCE INTEGRITY ===' AS summary,
    COUNT(*) AS total_patient_records,
    SUM(CASE WHEN ifirm.firm_id IS NULL THEN 1 ELSE 0 END) AS orphaned_records,
    SUM(CASE WHEN ifirm.firm_id IS NOT NULL THEN 1 ELSE 0 END) AS valid_records
FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id;

-- Records that still need attention
SELECT
    '=== RECORDS NEEDING ATTENTION ===' AS summary,
    COUNT(*) AS count
FROM insurance_firm
WHERE sync_status IN ('PAYER_ID_ONLY', 'NAME_ONLY', 'NO_MATCH')
   OR payer_id_fac IS NULL
   OR payer_id_pro IS NULL
   OR payer_id_elig IS NULL;

-- payer_id_new source breakdown
SELECT
    '=== PAYER_ID_NEW SOURCE ===' AS summary,
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'From fac'
        WHEN payer_id_pro IS NOT NULL THEN 'From pro'
        WHEN payer_id_elig IS NOT NULL THEN 'From elig'
        ELSE 'All NULL'
    END AS source,
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

-- ============================================================================
-- SECTION 5: CREATE VIEWS FOR ONGOING MONITORING
-- ============================================================================

-- View for records with mismatches
CREATE OR REPLACE VIEW v_insurance_firm_mismatches AS
SELECT
    firm_id,
    payer_id AS old_payer_id,
    payer_id_new AS new_payer_id,
    name AS old_name,
    name_new AS new_name,
    matched_via,
    sync_status,
    sync_details,
    last_synced_at
FROM insurance_firm
WHERE payer_id != payer_id_new
   OR name != name_new
ORDER BY name;

-- View for incomplete records
CREATE OR REPLACE VIEW v_insurance_firm_incomplete AS
SELECT
    firm_id,
    payer_id,
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig,
    sync_status,
    matched_via,
    CASE
        WHEN payer_id_fac IS NULL AND payer_id_pro IS NULL AND payer_id_elig IS NULL THEN
            'CRITICAL: All payer IDs missing'
        WHEN payer_id_fac IS NULL THEN 'WARNING: Missing facility ID'
        WHEN payer_id_pro IS NULL THEN 'WARNING: Missing professional ID'
        WHEN payer_id_elig IS NULL THEN 'WARNING: Missing eligibility ID'
        ELSE 'Minor issues'
    END AS severity
FROM insurance_firm
WHERE payer_id_fac IS NULL
   OR payer_id_pro IS NULL
   OR payer_id_elig IS NULL
ORDER BY severity DESC, name;

-- View for recently synced records
CREATE OR REPLACE VIEW v_insurance_firm_recent_sync AS
SELECT
    firm_id,
    payer_id,
    name,
    payer_id_new,
    name_new,
    matched_via,
    sync_status,
    last_synced_at
FROM insurance_firm
WHERE last_synced_at IS NOT NULL
ORDER BY last_synced_at DESC
LIMIT 100;

-- View for payer_id_new analysis
CREATE OR REPLACE VIEW v_insurance_firm_payer_id_analysis AS
SELECT
    firm_id,
    name,
    payer_id AS old_payer_id,
    payer_id_new AS new_payer_id,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig,
    matched_via,
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'fac'
        WHEN payer_id_pro IS NOT NULL THEN 'pro'
        WHEN payer_id_elig IS NOT NULL THEN 'elig'
        ELSE 'none'
    END AS primary_source,
    CASE
        WHEN payer_id = payer_id_fac THEN 'Old = fac'
        WHEN payer_id = payer_id_pro THEN 'Old = pro'
        WHEN payer_id = payer_id_elig THEN 'Old = elig'
        WHEN payer_id = payer_id_new THEN 'Old = new'
        ELSE 'Different'
    END AS old_vs_new_comparison
FROM insurance_firm
WHERE sync_status IS NOT NULL
ORDER BY name;

-- ============================================================================
-- SECTION 6: OPTIONAL - MIGRATE TO NEW VALUES
-- ============================================================================

-- ⚠️ ONLY RUN THIS AFTER VALIDATING THAT NEW VALUES ARE CORRECT ⚠️

-- Preview what will change
SELECT
    firm_id,
    payer_id AS current_payer_id,
    payer_id_new AS new_payer_id,
    name AS current_name,
    name_new AS new_name,
    matched_via,
    sync_status,
    'Will migrate to new values' AS action
FROM insurance_firm
WHERE (payer_id != payer_id_new OR name != name_new)
  AND sync_status IN ('EXACT_MATCH', 'PAYER_ID_ONLY', 'NAME_ONLY')
  AND payer_id_new IS NOT NULL
  AND name_new IS NOT NULL
ORDER BY name;

-- Uncomment below to execute migration (AFTER REVIEW!)
/*
UPDATE insurance_firm
SET
    payer_id = payer_id_new,
    name = name_new,
    sync_status = CONCAT('MIGRATED_', sync_status),
    sync_details = CONCAT('Migrated from "', payer_id, '" / "', name, '" to "', payer_id_new, '" / "', name_new, '" via ', matched_via),
    last_synced_at = CURRENT_TIMESTAMP
WHERE (payer_id != payer_id_new OR name != name_new)
  AND sync_status IN ('EXACT_MATCH', 'PAYER_ID_ONLY', 'NAME_ONLY')
  AND payer_id_new IS NOT NULL
  AND name_new IS NOT NULL;
*/
