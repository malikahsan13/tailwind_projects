-- ============================================================================
-- REVISED SYNC SCRIPT V2 - For OA with NULL payer_id but populated fac/pro/elig
-- ============================================================================
-- Matching logic: insurance_firm.payer_id matches OA's fac/pro/elig columns
-- payer_id_new determination: fac > pro > elig priority
-- ============================================================================

-- ============================================================================
-- PREPARATION: Add new columns if they don't exist
-- ============================================================================

-- Uncomment and run these if columns don't exist:
/*
ALTER TABLE `insurance_firm`
ADD COLUMN `payer_id_new` VARCHAR(200) NULL AFTER `payer_id`,
ADD COLUMN `name_new` VARCHAR(255) NULL AFTER `name`,
ADD COLUMN `sync_status` VARCHAR(50) NULL AFTER `wc_auto_elig`,
ADD COLUMN `sync_details` TEXT NULL AFTER `sync_status`,
ADD COLUMN `last_synced_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP AFTER `sync_details`,
ADD COLUMN `matched_via` VARCHAR(10) NULL AFTER `last_synced_at`;
-- matched_via will store which column matched: 'fac', 'pro', 'elig', or 'name'
*/

-- ============================================================================
-- PHASE 1: UPDATE EXISTING MATCHING RECORDS
-- ============================================================================

-- Step 1: Create match analysis
CREATE TEMPORARY TABLE IF NOT EXISTS insurance_firm_sync_analysis AS
SELECT
    ifirm.firm_id,
    ifirm.payer_id AS old_payer_id,
    ifirm.name AS old_name,

    -- Determine which payer_id to use as the "new" payer_id
    -- Priority: fac > pro > elig
    COALESCE(if_oa.payer_id_fac, if_oa.payer_id_pro, if_oa.payer_id_elig) AS new_payer_id,
    if_oa.name AS new_name,

    -- Determine match status
    CASE
        -- Exact match: old payer_id matches any of fac/pro/elig AND name matches
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
            THEN 'PAYER_ID_ONLY'

        -- Name only: name matches but payer_id doesn't match any
        WHEN IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
            THEN 'NAME_ONLY'

        -- No match
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

    -- All the data from insurance_firm_oa
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

-- Step 2: Preview what will be updated
SELECT
    'PHASE 1: RECORDS TO UPDATE' AS phase,
    match_status,
    matched_via,
    COUNT(*) AS count,
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

-- Sample of records to be updated
SELECT
    firm_id,
    old_payer_id,
    old_name,
    new_payer_id,
    new_name,
    match_status,
    matched_via,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig
FROM insurance_firm_sync_analysis
LIMIT 10;

-- Step 3: Execute the update for matching records
UPDATE insurance_firm tgt
SET
    -- NEW columns for correct values
    payer_id_new = ma.new_payer_id,
    name_new = ma.new_name,
    matched_via = ma.matched_via,

    -- Update all payer IDs
    payer_id_fac = ma.payer_id_fac,
    payer_id_fac_enrollment = ma.payer_id_fac_enrollment,
    payer_id_pro = ma.payer_id_pro,
    payer_id_pro_enrollment = ma.payer_id_pro_enrollment,
    payer_id_elig = ma.payer_id_elig,
    payer_id_elig_enrollment = ma.payer_id_elig_enrollment,

    -- Update all flags
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
        ELSE 'Unknown'
    END,
    last_synced_at = CURRENT_TIMESTAMP

FROM insurance_firm_sync_analysis ma
WHERE tgt.firm_id = ma.firm_id;

-- ============================================================================
-- PHASE 2: DELETE GARBAGE RECORDS
-- ============================================================================

-- Step 1: Preview what will be deleted
SELECT
    'PHASE 2: GARBAGE RECORDS TO DELETE' AS phase,
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

-- Check if these garbage records are referenced in patient_insurance
SELECT
    'GARBAGE RECORDS WITH PATIENT REFERENCES' AS warning,
    COUNT(DISTINCT ifirm.firm_id) AS firms_with_patients,
    COUNT(*) AS total_patient_references
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

-- Show which patient records will be affected
SELECT
    'PATIENT RECORDS THAT WILL BE ORPHANED' AS warning,
    pi.patient_insurance_id,
    ifirm.firm_id,
    ifirm.payer_id,
    ifirm.name
FROM patient_insurance pi
JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id_fac IS NULL
  AND if_oa.payer_id_pro IS NULL
  AND if_oa.payer_id_elig IS NULL
LIMIT 20;

-- ⚠️ CRITICAL DECISION POINT ⚠️
-- Choose ONE of the following options based on patient_insurance impact:

-- ============================================================================
-- OPTION A: Delete ONLY garbage records that have NO patient references
-- ============================================================================

-- This is the SAFE option - won't break any patient_insurance records
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
      AND pi.insurance_firm_id IS NULL  -- Only if no patient references
);

-- ============================================================================
-- OPTION B: Reassign patient_insurance before deleting
-- ============================================================================

/*
-- Step 1: Create mapping for reassignment
CREATE TEMPORARY TABLE temp_firm_reassignment AS
SELECT
    ifirm.firm_id AS old_firm_id,
    if_oa.firm_id AS new_firm_id
FROM insurance_firm ifirm
JOIN patient_insurance pi ON ifirm.firm_id = pi.insurance_firm_id
JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id_fac IS NOT NULL
  OR if_oa.payer_id_pro IS NOT NULL
  OR if_oa.payer_id_elig IS NOT NULL;

-- Step 2: Update patient_insurance to point to new firm
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

-- Step 3: Now delete the garbage records
DELETE FROM insurance_firm
WHERE firm_id IN (
    SELECT old_firm_id FROM temp_firm_reassignment
);
*/

-- ============================================================================
-- OPTION C: Delete ALL garbage records (including those with patient references)
-- ============================================================================

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
*/

-- ============================================================================
-- PHASE 3: INSERT NEW RECORDS FROM OA
-- ============================================================================

-- Step 1: Preview what will be inserted
SELECT
    'PHASE 3: NEW RECORDS TO INSERT FROM OA' AS phase,
    COUNT(*) AS count
FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id_fac = ifirm.payer_id
    OR if_oa.payer_id_pro = ifirm.payer_id
    OR if_oa.payer_id_elig = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL;

-- Sample of records to be inserted
SELECT
    name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig,
    COALESCE(payer_id_fac, payer_id_pro, payer_id_elig) AS will_be_payer_id
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
LIMIT 10;

-- Step 2: Insert new records from insurance_firm_oa
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
               ELSE 'none'
           END) AS sync_details,
    CURRENT_TIMESTAMP AS last_synced_at

FROM insurance_firm_oa if_oa
LEFT JOIN insurance_firm ifirm
    ON if_oa.payer_id_fac = ifirm.payer_id
    OR if_oa.payer_id_pro = ifirm.payer_id
    OR if_oa.payer_id_elig = ifirm.payer_id
    OR LOWER(if_oa.name) = LOWER(ifirm.name)
WHERE ifirm.firm_id IS NULL;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Final sync status distribution
SELECT
    'FINAL SYNC STATUS DISTRIBUTION' AS info,
    sync_status,
    matched_via,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
GROUP BY sync_status, matched_via
ORDER BY count DESC;

-- Compare row counts
SELECT
    'FINAL ROW COUNTS' AS info,
    (SELECT COUNT(*) FROM insurance_firm) AS insurance_firm_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) AS insurance_firm_oa_count,
    (SELECT COUNT(*) FROM insurance_firm) - (SELECT COUNT(*) FROM insurance_firm_oa) AS difference;

-- Check for orphaned patient_insurance records
SELECT
    'ORPHANED PATIENT INSURANCE RECORDS' AS warning,
    COUNT(*) AS orphaned_count
FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
WHERE ifirm.firm_id IS NULL;

-- Verify NULL values in critical fields
SELECT
    'NULL VALUES CHECK' AS info,
    SUM(CASE WHEN payer_id_fac IS NULL THEN 1 ELSE 0 END) AS null_fac,
    SUM(CASE WHEN payer_id_pro IS NULL THEN 1 ELSE 0 END) AS null_pro,
    SUM(CASE WHEN payer_id_elig IS NULL THEN 1 ELSE 0 END) AS null_elig,
    SUM(CASE WHEN payer_id_new IS NULL THEN 1 ELSE 0 END) AS null_payer_id_new,
    SUM(CASE WHEN name_new IS NULL THEN 1 ELSE 0 END) AS null_name_new,
    COUNT(*) AS total_records
FROM insurance_firm;

-- Check payer_id_new determination strategy
SELECT
    'PAYER_ID_NEW SOURCE BREAKDOWN' AS info,
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'From fac'
        WHEN payer_id_pro IS NOT NULL THEN 'From pro'
        WHEN payer_id_elig IS NOT NULL THEN 'From elig'
        ELSE 'NULL (all three are NULL)'
    END AS payer_id_new_source,
    COUNT(*) AS count
FROM insurance_firm
WHERE sync_status IS NOT NULL
GROUP BY
    CASE
        WHEN payer_id_fac IS NOT NULL THEN 'From fac'
        WHEN payer_id_pro IS NOT NULL THEN 'From pro'
        WHEN payer_id_elig IS NOT NULL THEN 'From elig'
        ELSE 'NULL (all three are NULL)'
    END
ORDER BY count DESC;

-- Sample of updated records
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
LIMIT 20;

-- Clean up temporary table
DROP TEMPORARY TABLE IF EXISTS insurance_firm_sync_analysis;
