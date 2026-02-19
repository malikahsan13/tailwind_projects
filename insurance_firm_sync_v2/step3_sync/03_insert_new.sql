-- ============================================================================
-- STEP 3.3: INSERT NEW RECORDS FROM OA
-- ============================================================================
-- Purpose: Phase 3 - Insert records from insurance_firm_oa that don't exist in insurance_firm
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Preview: Show what will be inserted
-- ----------------------------------------------------------------------------
SELECT
    '=== RECORDS TO INSERT (PREVIEW) ===' AS preview,
    COUNT(*) AS insert_count,
    'These records exist in OA but not in insurance_firm' AS reason
FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id_fac = ifirm.payer_id
    OR if_oa.payer_id_pro = ifirm.payer_id
    OR if_oa.payer_id_elig = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL;

-- ----------------------------------------------------------------------------
-- Sample of records to be inserted
-- ----------------------------------------------------------------------------
SELECT
    '=== SAMPLE NEW RECORDS FROM OA ===' AS sample,
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig,
    COALESCE(payer_id_fac, payer_id_pro, payer_id_elig) AS will_be_payer_id,
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'fac'
        WHEN payer_id_pro IS NOT NULL THEN 'pro'
        WHEN payer_id_elig IS NOT NULL THEN 'elig'
        ELSE 'none'
    END AS primary_payer_source
FROM insurance_firm_oa
WHERE (payer_id_fac, payer_id_pro, payer_id_elig, name) IN (
    SELECT if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig, if_oa.name
    FROM insurance_firm_oa if_oa
    LEFT JOIN insurance_firm ifirm
        ON if_oa.payer_id_fac = ifirm.payer_id
        OR if_oa.payer_id_pro = ifirm.payer_id
        OR if_oa.payer_id_elig = ifirm.payer_id
        OR LOWER(if_oa.name) = LOWER(ifirm.name)
    WHERE ifirm.firm_id IS NULL
)
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Execute: Insert new records from insurance_firm_oa
-- ----------------------------------------------------------------------------
INSERT INTO insurance_firm (
    -- Basic info
    payer_id,
    name,
    payer_id_new,
    name_new,
    matched_via,

    -- Payer IDs
    payer_id_fac,
    payer_id_fac_enrollment,
    payer_id_pro,
    payer_id_pro_enrollment,
    payer_id_elig,
    payer_id_elig_enrollment,

    -- Flags
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

    -- Sync tracking
    sync_status,
    sync_details,
    last_synced_at
)
SELECT
    -- Basic info
    -- Use COALESCE to pick first available: fac > pro > elig
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

    -- Payer IDs
    if_oa.payer_id_fac,
    if_oa.payer_id_fac_enrollment,
    if_oa.payer_id_pro,
    if_oa.payer_id_pro_enrollment,
    if_oa.payer_id_elig,
    if_oa.payer_id_elig_enrollment,

    -- Flags
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

    -- Sync tracking
    'NEW_FROM_OA' AS sync_status,
    CONCAT('New record from OA. Primary payer ID: ',
           CASE
               WHEN if_oa.payer_id_fac IS NOT NULL THEN 'fac'
               WHEN if_oa.payer_id_pro IS NOT NULL THEN 'pro'
               WHEN if_oa.payer_id_elig IS NOT NULL THEN 'elig'
               ELSE 'none (all NULL)'
           END) AS sync_details,
    CURRENT_TIMESTAMP AS last_synced_at

FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id_fac = ifirm.payer_id
    OR if_oa.payer_id_pro = ifirm.payer_id
    OR if_oa.payer_id_elig = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL;

-- ----------------------------------------------------------------------------
-- Results: Show what was inserted
-- ----------------------------------------------------------------------------
SELECT
    '=== PHASE 3 COMPLETE ===' AS status,
    ROW_COUNT() AS records_inserted,
    'New records from OA have been inserted' AS description;

-- ----------------------------------------------------------------------------
-- Verification: Compare row counts
-- ----------------------------------------------------------------------------
SELECT
    '=== ROW COUNT COMPARISON ===' AS comparison,
    (SELECT COUNT(*) FROM insurance_firm) AS insurance_firm_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) AS insurance_firm_oa_count,
    ABS((SELECT COUNT(*) FROM insurance_firm) - (SELECT COUNT(*) FROM insurance_firm_oa)) AS difference,
    CASE
        WHEN (SELECT COUNT(*) FROM insurance_firm) = (SELECT COUNT(*) FROM insurance_firm_oa) THEN
            '✓ Perfect match - counts are equal'
        WHEN ABS((SELECT COUNT(*) FROM insurance_firm) - (SELECT COUNT(*) FROM insurance_firm_oa)) <= 5 THEN
            '⚠ Close match - small difference expected'
        ELSE
            '⚠ Significant difference - review remaining records'
    END AS status;

-- ----------------------------------------------------------------------------
-- Sample of inserted records
-- ----------------------------------------------------------------------------
SELECT
    firm_id,
    payer_id,
    name,
    payer_id_new,
    name_new,
    matched_via,
    sync_status,
    sync_details,
    last_synced_at
FROM insurance_firm
WHERE sync_status = 'NEW_FROM_OA'
ORDER BY firm_id DESC
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Check for any remaining records without sync_status
-- ----------------------------------------------------------------------------
SELECT
    '=== UNSYNCED RECORDS (if any) ===' AS check_type,
    COUNT(*) AS unsynced_count,
    CASE
        WHEN COUNT(*) = 0 THEN '✓ All records have been synced'
        ELSE '⚠ Some records not synced - may need manual review'
    END AS status
FROM insurance_firm
WHERE sync_status IS NULL;

-- If any unsynced records exist, show them
SELECT
    firm_id,
    payer_id,
    name
FROM insurance_firm
WHERE sync_status IS NULL
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Overall sync status distribution
-- ----------------------------------------------------------------------------
SELECT
    '=== OVERALL SYNC STATUS DISTRIBUTION ===' AS distribution,
    sync_status,
    matched_via,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
GROUP BY sync_status, matched_via
ORDER BY
    CASE sync_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        WHEN 'NEW_FROM_OA' THEN 4
        ELSE 5
    END,
    matched_via;

-- ----------------------------------------------------------------------------
-- Phase 3 completion summary
-- ----------------------------------------------------------------------------
SELECT
    '=== PHASE 3 SUMMARY ===' AS summary,
    '✓ PHASE 1: Update matching records' AS phase1,
    '✓ PHASE 2: Delete garbage records' AS phase2,
    '✓ PHASE 3: Insert new records' AS phase3,
    'ALL PHASES COMPLETE' AS overall_status,
    'Next: Run step4_verify scripts for final verification' AS next_step;
