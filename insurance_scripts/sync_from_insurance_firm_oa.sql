-- ============================================================================
-- SYNC insurance_firm FROM insurance_firm_oa (Flattened Source of Truth)
-- ============================================================================
-- This script updates insurance_firm with correct data from insurance_firm_oa
-- and adds match quality flags for tracking
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 0: Backup before running (UNCOMMENT TO USE)
-- ----------------------------------------------------------------------------
-- CREATE TABLE insurance_firm_backup_YYYYMMDD AS SELECT * FROM insurance_firm;

-- ----------------------------------------------------------------------------
-- STEP 1: First, identify matching records and determine match quality
-- ----------------------------------------------------------------------------

-- Create a temporary table to store match analysis
CREATE TEMPORARY TABLE IF NOT EXISTS insurance_firm_match_analysis AS
SELECT
    ifirm.firm_id,
    ifirm.payer_id AS current_payer_id,
    ifirm.name AS current_name,
    if_oa.payer_id AS correct_payer_id,
    if_oa.name AS correct_name,

    -- Determine match status
    CASE
        -- Exact match: both payer_id and name match
        WHEN IFNULL(ifirm.payer_id, '') = IFNULL(if_oa.payer_id, '')
         AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
            THEN 'EXACT_MATCH'

        -- Only payer_id matches (name differs)
        WHEN IFNULL(ifirm.payer_id, '') = IFNULL(if_oa.payer_id, '')
         AND IFNULL(LOWER(ifirm.name), '') != IFNULL(LOWER(if_oa.name), '')
            THEN 'PAYER_ID_ONLY'

        -- Only name matches (payer_id differs)
        WHEN IFNULL(ifirm.payer_id, '') != IFNULL(if_oa.payer_id, '')
         AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(if_oa.name), '')
            THEN 'NAME_ONLY'

        -- No match
        ELSE 'NO_MATCH'
    END AS match_status,

    -- All the correct data from insurance_firm_oa
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
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id
    OR LOWER(ifirm.name) = LOWER(if_oa.name);

-- ----------------------------------------------------------------------------
-- STEP 2: Preview the match analysis before updating
-- ----------------------------------------------------------------------------

-- Summary of matches
SELECT
    'MATCH SUMMARY' AS info,
    match_status,
    COUNT(*) AS record_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm_match_analysis
GROUP BY match_status
ORDER BY
    CASE match_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        WHEN 'NO_MATCH' THEN 4
        ELSE 5
    END;

-- Sample of exact matches (should be safe to update)
SELECT
    firm_id,
    current_payer_id,
    current_name,
    correct_payer_id,
    correct_name,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig
FROM insurance_firm_match_analysis
WHERE match_status = 'EXACT_MATCH'
LIMIT 10;

-- Sample of problematic matches (need manual review)
SELECT
    firm_id,
    current_payer_id,
    current_name,
    correct_payer_id,
    correct_name,
    match_status,
    'Current: "' || current_name || '" -> Correct: "' || correct_name || '"' AS issue
FROM insurance_firm_match_analysis
WHERE match_status IN ('PAYER_ID_ONLY', 'NAME_ONLY', 'NO_MATCH')
LIMIT 20;

-- ----------------------------------------------------------------------------
-- STEP 3: Execute the update (Run after reviewing the above!)
-- ----------------------------------------------------------------------------

-- UPDATE insurance_firm with matched data
UPDATE insurance_firm tgt
SET
    -- Update all payer IDs and flags from insurance_firm_oa
    payer_id_fac = ma.payer_id_fac,
    payer_id_fac_enrollment = ma.payer_id_fac_enrollment,
    payer_id_pro = ma.payer_id_pro,
    payer_id_pro_enrollment = ma.payer_id_pro_enrollment,
    payer_id_elig = ma.payer_id_elig,
    payer_id_elig_enrollment = ma.payer_id_elig_enrollment,
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
    wc_auto_elig = ma.wc_auto_elig

FROM insurance_firm_match_analysis ma
WHERE tgt.firm_id = ma.firm_id
  AND ma.match_status != 'NO_MATCH';  -- Only update if we found a match

-- ----------------------------------------------------------------------------
-- STEP 4: Add match tracking columns (if not already present)
-- ----------------------------------------------------------------------------

-- Check if match_status column exists, if not add it
-- ALTER TABLE insurance_firm
-- ADD COLUMN IF NOT EXISTS match_status VARCHAR(20),
-- ADD COLUMN IF NOT EXISTS match_details TEXT,
-- ADD COLUMN IF NOT EXISTS correct_name_from_oa VARCHAR(255),
-- ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMP;

-- ----------------------------------------------------------------------------
-- STEP 5: Update match tracking columns
-- ----------------------------------------------------------------------------

UPDATE insurance_firm tgt
SET
    match_status = ma.match_status,
    match_details = CASE
        WHEN ma.match_status = 'EXACT_MATCH' THEN
            'Perfect match. Data synced from insurance_firm_oa.'
        WHEN ma.match_status = 'PAYER_ID_ONLY' THEN
            'Payer ID matches but name differs. Old: "' || tgt.name || '", New: "' || ma.correct_name || '"'
        WHEN ma.match_status = 'NAME_ONLY' THEN
            'Name matches but payer_id differs. Old: "' || tgt.payer_id || '", New: "' || ma.correct_payer_id || '"'
        WHEN ma.match_status = 'NO_MATCH' THEN
            'No matching record found in insurance_firm_oa'
        ELSE 'Unknown'
    END,
    correct_name_from_oa = ma.correct_name,
    last_synced_at = CURRENT_TIMESTAMP
FROM insurance_firm_match_analysis ma
WHERE tgt.firm_id = ma.firm_id;

-- ----------------------------------------------------------------------------
-- STEP 6: Verification Queries
-- ----------------------------------------------------------------------------

-- Check how many records were updated
SELECT
    'Records Updated' AS status,
    COUNT(*) AS count
FROM insurance_firm
WHERE payer_id_fac IS NOT NULL
   OR payer_id_pro IS NOT NULL
   OR payer_id_elig IS NOT NULL;

-- Check for any NULL values in critical fields
SELECT
    'NULL Values Check' AS status,
    SUM(CASE WHEN payer_id_fac IS NULL THEN 1 ELSE 0 END) AS null_fac,
    SUM(CASE WHEN payer_id_pro IS NULL THEN 1 ELSE 0 END) AS null_pro,
    SUM(CASE WHEN payer_id_elig IS NULL THEN 1 ELSE 0 END) AS null_elig,
    COUNT(*) AS total_records
FROM insurance_firm;

-- Verify patient_insurance still has valid references
SELECT
    'Orphaned Patient Insurance Records' AS status,
    COUNT(*) AS orphaned_count
FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
WHERE ifirm.firm_id IS NULL;

-- ----------------------------------------------------------------------------
-- STEP 7: Create view for manual review of problematic records
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_insurance_firm_review AS
SELECT
    firm_id,
    payer_id AS current_payer_id,
    name AS current_name,
    match_status,
    match_details,
    correct_name_from_oa,
    payer_id_fac,
    payer_id_pro,
    payer_id_elig,
    last_synced_at
FROM insurance_firm
WHERE match_status IN ('PAYER_ID_ONLY', 'NAME_ONLY', 'NO_MATCH')
ORDER BY
    CASE match_status
        WHEN 'PAYER_ID_ONLY' THEN 1
        WHEN 'NAME_ONLY' THEN 2
        WHEN 'NO_MATCH' THEN 3
        ELSE 4
    END,
    name;

-- Drop the temporary table when done
-- DROP TEMPORARY TABLE IF EXISTS insurance_firm_match_analysis;
