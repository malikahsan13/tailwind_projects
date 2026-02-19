-- ============================================================================
-- STEP 3.2: DELETE GARBAGE RECORDS
-- ============================================================================
-- Purpose: Phase 2 - Delete records not in insurance_firm_oa
-- IMPORTANT: Choose ONE option (A, B, or C) based on STEP 2 patient impact
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Preview: Show what will be deleted
-- ----------------------------------------------------------------------------
SELECT
    '=== RECORDS TO DELETE (PREVIEW) ===' AS preview,
    COUNT(*) AS garbage_count,
    'These records do not exist in insurance_firm_oa' AS reason
FROM insurance_firm ifirm
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id_fac IS NULL
  AND if_oa.payer_id_pro IS NULL
  AND if_oa.payer_id_elig IS NULL;

-- Show sample of records to be deleted
SELECT
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
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Check patient impact BEFORE deleting
-- ----------------------------------------------------------------------------
SELECT
    '=== PATIENT_IMPACT CHECK ===' AS impact_check,
    COUNT(DISTINCT ifirm.firm_id) AS firms_with_patients,
    COUNT(*) AS total_patient_records,
    CASE
        WHEN COUNT(*) = 0 THEN '✓ SAFE TO DELETE (no patient impact)'
        WHEN COUNT(*) < 10 THEN '⚠ LOW IMPACT - Review manually'
        ELSE '⚠ HIGH IMPACT - Use Option B or C'
    END AS recommendation
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

-- ============================================================================
-- ⚠️ CRITICAL: CHOOSE ONE OPTION BELOW ⚠️
-- ============================================================================

-- ----------------------------------------------------------------------------
-- OPTION A: SAFE DELETION (RECOMMENDED FIRST CHOICE)
-- Deletes ONLY garbage records that have NO patient_insurance references
-- This is the safest option and won't break any patient records
-- ----------------------------------------------------------------------------

DELETE FROM insurance_firm
WHERE firm_id IN (
    SELECT ifirm.firm_id
    FROM insurance_firm ifirm
    LEFT JOIN insurance_firm_oa if_oa
        ON ifirm.payer_id = if_oa.payer_id_fac
        OR ifirm.payer_id = if_oa.payer_id_pro
        OR ifirm.payer_id = if_oa.payer_id_elig
        OR LOWER(ifirm.name) = LOWER(if_oa.name)
    LEFT JOIN patient_insurance pi
        ON ifirm.firm_id = pi.insurance_firm_id
    WHERE if_oa.payer_id_fac IS NULL
      AND if_oa.payer_id_pro IS NULL
      AND if_oa.payer_id_elig IS NULL
      AND pi.insurance_firm_id IS NULL  -- Only delete if no patient refs
);

SELECT
    '✓ OPTION A COMPLETE' AS status,
    ROW_COUNT() AS records_deleted,
    'Safe deletion: Only records with no patient references' AS description;


-- ----------------------------------------------------------------------------
-- OPTION B: REASSIGN THEN DELETE (USE IF PATIENT_IMPACT > 0)
-- Reassigns patient_insurance to matching OA records, then deletes garbage
-- Only uncomment and use this if you have patient impact and want to reassign
-- ----------------------------------------------------------------------------

/*
-- Step B1: Create reassignment mapping
CREATE TEMPORARY TABLE temp_firm_reassignment AS
SELECT
    ifirm.firm_id AS old_firm_id,
    ifirm.firm_id AS new_firm_id,
    ifirm.payer_id AS old_payer_id,
    if_oa.name AS oa_name
FROM insurance_firm ifirm
INNER JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id_fac IS NOT NULL
  OR if_oa.payer_id_pro IS NOT NULL
  OR if_oa.payer_id_elig IS NOT NULL;

-- Preview reassignments
SELECT
    '=== REASSIGNMENT PREVIEW ===' AS preview,
    old_firm_id,
    new_firm_id,
    old_payer_id,
    oa_name,
    COUNT(*) AS patient_count
FROM temp_firm_reassignment tr
JOIN patient_insurance pi ON tr.old_firm_id = pi.insurance_firm_id
GROUP BY old_firm_id, new_firm_id, old_payer_id, oa_name
ORDER BY patient_count DESC;

-- Step B2: Update patient_insurance with new firm_id
UPDATE patient_insurance pi
SET insurance_firm_id = (
    SELECT new_firm_id
    FROM temp_firm_reassignment
    WHERE old_firm_id = pi.insurance_firm_id
)
WHERE EXISTS (
    SELECT 1 FROM temp_firm_reassignment
    WHERE old_firm_id = pi.insurance_firm_id
);

SELECT
    '✓ PATIENT REASSIGNMENT COMPLETE' AS status,
    ROW_COUNT() AS patients_reassigned,
    'Patient records updated to point to new firms' AS description;

-- Step B3: Now delete the garbage records
DELETE FROM insurance_firm
WHERE firm_id IN (
    SELECT old_firm_id FROM temp_firm_reassignment
);

SELECT
    '✓ OPTION B COMPLETE' AS status,
    ROW_COUNT() AS garbage_records_deleted,
    'Reassignment + Deletion complete' AS description;

-- Clean up
DROP TEMPORARY TABLE temp_firm_reassignment;
*/


-- ----------------------------------------------------------------------------
-- OPTION C: DELETE ALL (DANGEROUS - WILL ORPHAN PATIENT RECORDS)
-- Deletes ALL garbage records including those with patient references
-- Only use this if you plan to handle orphans in post-sync cleanup
-- ----------------------------------------------------------------------------

/*
DELETE FROM insurance_firm
WHERE firm_id IN (
    SELECT ifirm.firm_id
    FROM insurance_firm ifirm
    LEFT JOIN insurance_firm_oa if_oa
        ON ifirm.payer_id = if_oa.payer_id_fac
        OR ifirm.payer_id = if_oa.payer_id_pro
        OR ifirm.payer_id = if_oa.payer_id_elig
        OR LOWER(ifirm.name) = LOWER(if_oa.name)
    WHERE if_oa.payer_id_fac IS NULL
      AND if_oa.payer_id_pro IS NULL
      AND if_oa.payer_id_elig IS NULL
);

SELECT
    '✓ OPTION C COMPLETE' AS status,
    ROW_COUNT() AS records_deleted,
    '⚠ WARNING: Some patient records may be orphaned' AS description,
    'Run step4_verify/03_patient_integrity.sql to check orphans' AS next_step;
*/

-- ============================================================================
-- END OF OPTIONS - ONLY USE ONE OPTION ABOVE
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Verification: Show remaining records
-- ----------------------------------------------------------------------------
SELECT
    '=== PHASE 2 VERIFICATION ===' AS verification,
    (SELECT COUNT(*) FROM insurance_firm) AS current_firm_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) AS oa_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) - (SELECT COUNT(*) FROM insurance_firm) AS remaining_difference;

-- ----------------------------------------------------------------------------
-- Check for remaining garbage (if Option A was used)
-- ----------------------------------------------------------------------------
SELECT
    '=== REMAINING GARBAGE (if any) ===' AS remaining,
    COUNT(*) AS remaining_garbage_count,
    CASE
        WHEN COUNT(*) = 0 THEN '✓ All garbage deleted'
        ELSE '⚠ Some garbage remains (has patient references)'
    END AS status
FROM insurance_firm ifirm
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id_fac IS NULL
  AND if_oa.payer_id_pro IS NULL
  AND if_oa.payer_id_elig IS NULL;

-- ----------------------------------------------------------------------------
-- Next step message
-- ----------------------------------------------------------------------------
SELECT
    '✓ PHASE 2 COMPLETE' AS status,
    'Garbage records deleted based on chosen option' AS message,
    'Next: Run 03_insert_new.sql to add missing records from OA' AS next_step;
