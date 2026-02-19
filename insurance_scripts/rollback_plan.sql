-- ============================================================================
-- ROLLBACK PLAN - If anything goes wrong
-- ============================================================================

-- IMPORTANT: Always backup before running the solution!

-- Option 1: If you created a backup table
-- DROP TABLE insurance_firm;
-- CREATE TABLE insurance_firm AS SELECT * FROM insurance_firm_backup;

-- Option 2: If you want to revert just the column changes (keep backup)
-- ALTER TABLE insurance_firm DROP COLUMN IF EXISTS facility_payer_id;
-- ALTER TABLE insurance_firm DROP COLUMN IF EXISTS professional_payer_id;
-- ALTER TABLE insurance_firm DROP COLUMN IF EXISTS eligibility_payer_id;
-- ALTER TABLE insurance_firm DROP COLUMN IF EXISTS match_status;
-- ALTER TABLE insurance_firm DROP COLUMN IF EXISTS match_details;
-- ALTER TABLE insurance_firm DROP COLUMN IF EXISTS name_from_payers_oa;
-- ALTER TABLE insurance_firm DROP COLUMN IF EXISTS last_synced_at;

-- Option 3: Undo data updates (keep columns but restore values)
-- This requires a backup table with original values
/*
UPDATE insurance_firm
SET
    facility_payer_id = NULL,
    professional_payer_id = NULL,
    eligibility_payer_id = NULL,
    match_status = NULL,
    match_details = NULL,
    name_from_payers_oa = NULL,
    last_synced_at = NULL;
*/
