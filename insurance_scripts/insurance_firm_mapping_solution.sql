-- ============================================================================
-- SOLUTION: Map and Sync insurance_firm with payers_oa table
-- ============================================================================
-- Problem: insurance_firm has invalid payer_id and name
-- Solution: Add facility, professional, eligibility payer_id columns
--          Match with payers_oa and add match quality flags
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Add new columns to insurance_firm table
-- ----------------------------------------------------------------------------
-- First, backup your data before running this!
-- CREATE TABLE insurance_firm_backup AS SELECT * FROM insurance_firm;

ALTER TABLE insurance_firm
ADD COLUMN IF NOT EXISTS facility_payer_id VARCHAR(50),
ADD COLUMN IF NOT EXISTS professional_payer_id VARCHAR(50),
ADD COLUMN IF NOT EXISTS eligibility_payer_id VARCHAR(50),
ADD COLUMN IF NOT EXISTS match_status VARCHAR(50),
ADD COLUMN IF NOT EXISTS match_details TEXT,
ADD COLUMN IF NOT EXISTS name_from_payers_oa VARCHAR(255),
ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMP;

-- ----------------------------------------------------------------------------
-- STEP 2: Create a CTE to pivot payers_oa data (3 rows -> 1 row per payer)
-- ----------------------------------------------------------------------------
WITH pivoted_payers AS (
    SELECT
        payer_id,
        name,
        MAX(CASE WHEN transaction LIKE '%Professional%' THEN payer_id END) AS professional_payer_id,
        MAX(CASE WHEN transaction LIKE '%Institutional%' OR transaction LIKE '%Facility%' THEN payer_id END) AS facility_payer_id,
        MAX(CASE WHEN transaction LIKE '%Eligibility%' THEN payer_id END) AS eligibility_payer_id
    FROM payers_oa
    GROUP BY payer_id, name
),

-- ----------------------------------------------------------------------------
-- STEP 3: Match insurance_firm with payers_oa and determine match quality
-- ----------------------------------------------------------------------------
match_analysis AS (
    SELECT
        ifirm.firm_id,
        ifirm.payer_id AS current_payer_id,
        ifirm.name AS current_name,
        pp.payer_id AS matched_payer_id,
        pp.name AS matched_name,
        pp.facility_payer_id,
        pp.professional_payer_id,
        pp.eligibility_payer_id,

        -- Determine match status
        CASE
            -- Exact match: both payer_id and name match
            WHEN ifirm.payer_id = pp.payer_id AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(pp.name), '')
                THEN 'EXACT_MATCH'

            -- Only payer_id matches (name differs)
            WHEN ifirm.payer_id = pp.payer_id AND IFNULL(LOWER(ifirm.name), '') != IFNULL(LOWER(pp.name), '')
                THEN 'PAYER_ID_ONLY'

            -- Only name matches (payer_id differs)
            WHEN ifirm.payer_id != pp.payer_id AND IFNULL(LOWER(ifirm.name), '') = IFNULL(LOWER(pp.name), '')
                THEN 'NAME_ONLY'

            -- No match
            ELSE 'NO_MATCH'
        END AS match_status

    FROM insurance_firm ifirm
    LEFT JOIN pivoted_payers pp
        ON ifirm.payer_id = pp.payer_id
        OR LOWER(ifirm.name) = LOWER(pp.name)
)

-- ----------------------------------------------------------------------------
-- STEP 4: Update insurance_firm with matched data
-- ----------------------------------------------------------------------------
UPDATE insurance_firm tgt
SET
    facility_payer_id = ma.facility_payer_id,
    professional_payer_id = ma.professional_payer_id,
    eligibility_payer_id = ma.eligibility_payer_id,
    match_status = ma.match_status,
    match_details = CASE
        WHEN ma.match_status = 'EXACT_MATCH' THEN
            CONCAT('Perfect match. Current payer_id: ', tgt.payer_id, ', Correct name: ', ma.matched_name)
        WHEN ma.match_status = 'PAYER_ID_ONLY' THEN
            CONCAT('Payer ID matches but name differs. Current: "', tgt.name, '", Correct: "', ma.matched_name, '"')
        WHEN ma.match_status = 'NAME_ONLY' THEN
            CONCAT('Name matches but payer_id differs. Current ID: ', tgt.payer_id, ', Correct ID: ', ma.matched_payer_id)
        WHEN ma.match_status = 'NO_MATCH' THEN
            'No matching record found in payers_oa'
        ELSE 'Unknown match status'
    END,
    name_from_payers_oa = ma.matched_name,
    last_synced_at = CURRENT_TIMESTAMP
FROM match_analysis ma
WHERE tgt.firm_id = ma.firm_id;

-- ----------------------------------------------------------------------------
-- STEP 5: If exact match, optionally update the name and payer_id to correct values
-- ----------------------------------------------------------------------------
-- Uncomment below if you want to auto-correct exact matches
/*
UPDATE insurance_firm
SET
    payer_id = matched.payer_id,
    name = matched.name
FROM (
    SELECT payer_id, name FROM payers_oa
) matched
WHERE insurance_firm.match_status = 'EXACT_MATCH'
  AND insurance_firm.payer_id != matched.payer_id;
*/

-- ----------------------------------------------------------------------------
-- STEP 6: Create a view for manual review of problematic records
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_insurance_firm_review AS
SELECT
    firm_id,
    payer_id AS current_payer_id,
    name AS current_name,
    facility_payer_id,
    professional_payer_id,
    eligibility_payer_id,
    match_status,
    match_details,
    name_from_payers_oa AS suggested_name,
    last_synced_at
FROM insurance_firm
WHERE match_status IN ('PAYER_ID_ONLY', 'NAME_ONLY', 'NO_MATCH')
ORDER BY
    CASE match_status
        WHEN 'PAYER_ID_ONLY' THEN 1
        WHEN 'NAME_ONLY' THEN 2
        WHEN 'NO_MATCH' THEN 3
        ELSE 4
    END;

-- ----------------------------------------------------------------------------
-- STEP 7: Query to see summary of match results
-- ----------------------------------------------------------------------------
SELECT
    match_status,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
GROUP BY match_status
ORDER BY
    CASE match_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        WHEN 'NO_MATCH' THEN 4
        ELSE 5
    END;

-- ============================================================================
-- RECOMMENDED FOLLOW-UP ACTIONS
-- ============================================================================

-- 1. Review exact matches (should be auto-corrected):
-- SELECT firm_id, payer_id, name, name_from_payers_oa
-- FROM insurance_firm
-- WHERE match_status = 'EXACT_MATCH';

-- 2. Review payer_id only matches (names differ - investigate):
-- SELECT * FROM v_insurance_firm_review WHERE match_status = 'PAYER_ID_ONLY';

-- 3. Review name only matches (payer_ids differ - investigate):
-- SELECT * FROM v_insurance_firm_review WHERE match_status = 'NAME_ONLY';

-- 4. Review no matches (need manual intervention or new payer creation):
-- SELECT * FROM v_insurance_firm_review WHERE match_status = 'NO_MATCH';

-- 5. Check impact on patient_insurance table:
-- SELECT COUNT(*) FROM patient_insurance WHERE insurance_firm_id IN (
--     SELECT firm_id FROM insurance_firm WHERE match_status != 'EXACT_MATCH'
-- );
