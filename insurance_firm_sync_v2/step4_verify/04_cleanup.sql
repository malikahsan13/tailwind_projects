-- ============================================================================
-- STEP 4.4: FINAL CLEANUP AND MONITORING VIEWS
-- ============================================================================
-- Purpose: Create views for ongoing monitoring and final cleanup
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Drop existing views if they exist
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_insurance_firm_mismatches;
DROP VIEW IF EXISTS v_insurance_firm_incomplete;
DROP VIEW IF EXISTS v_insurance_firm_recent_sync;
DROP VIEW IF EXISTS v_insurance_firm_payer_id_analysis;
DROP VIEW IF EXISTS v_insurance_firm_sync_dashboard;

-- ----------------------------------------------------------------------------
-- View 1: Records with mismatches (old vs new)
-- ----------------------------------------------------------------------------
CREATE VIEW v_insurance_firm_mismatches AS
SELECT
    firm_id,
    payer_id AS old_payer_id,
    payer_id_new AS new_payer_id,
    name AS old_name,
    name_new AS new_name,
    matched_via,
    sync_status,
    sync_details,
    last_synced_at,
    CASE
        WHEN payer_id != payer_id_new AND name != name_new THEN 'Both differ'
        WHEN payer_id != payer_id_new THEN 'Only payer_id differs'
        WHEN name != name_new THEN 'Only name differs'
        ELSE 'Match'
    END AS mismatch_type
FROM insurance_firm
WHERE payer_id != payer_id_new
   OR name != name_new
ORDER BY
    CASE sync_status
        WHEN 'EXACT_MATCH' THEN 1
        WHEN 'PAYER_ID_ONLY' THEN 2
        WHEN 'NAME_ONLY' THEN 3
        ELSE 4
    END,
    name;

-- ----------------------------------------------------------------------------
-- View 2: Incomplete records (missing payer IDs)
-- ----------------------------------------------------------------------------
CREATE VIEW v_insurance_firm_incomplete AS
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
    END AS severity,
    (
        CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END
    ) AS completeness_count
FROM insurance_firm
WHERE payer_id_fac IS NULL
   OR payer_id_pro IS NULL
   OR payer_id_elig IS NULL
ORDER BY
    (
        CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END
    ) ASC,
    name;

-- ----------------------------------------------------------------------------
-- View 3: Recently synced records
-- ----------------------------------------------------------------------------
CREATE VIEW v_insurance_firm_recent_sync AS
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

-- ----------------------------------------------------------------------------
-- View 4: Payer ID analysis
-- ----------------------------------------------------------------------------
CREATE VIEW v_insurance_firm_payer_id_analysis AS
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
    END AS old_vs_new_comparison,
    sync_status
FROM insurance_firm
WHERE sync_status IS NOT NULL
ORDER BY name;

-- ----------------------------------------------------------------------------
-- View 5: Sync dashboard (overall stats)
-- ----------------------------------------------------------------------------
CREATE VIEW v_insurance_firm_sync_dashboard AS
SELECT
    'Total Records' AS metric,
    COUNT(*) AS value,
    '%' AS unit
FROM insurance_firm

UNION ALL

SELECT
    'Exact Matches',
    COUNT(*),
    '%'
FROM insurance_firm
WHERE sync_status = 'EXACT_MATCH'

UNION ALL

SELECT
    'Needs Review',
    COUNT(*),
    '%'
FROM insurance_firm
WHERE sync_status IN ('PAYER_ID_ONLY', 'NAME_ONLY')

UNION ALL

SELECT
    'New from OA',
    COUNT(*),
    '%'
FROM insurance_firm
WHERE sync_status = 'NEW_FROM_OA'

UNION ALL

SELECT
    'Has fac ID',
    COUNT(*),
    '%'
FROM insurance_firm
WHERE payer_id_fac IS NOT NULL

UNION ALL

SELECT
    'Has pro ID',
    COUNT(*),
    '%'
FROM insurance_firm
WHERE payer_id_pro IS NOT NULL

UNION ALL

SELECT
    'Has elig ID',
    COUNT(*),
    '%'
FROM insurance_firm
WHERE payer_id_elig IS NOT NULL;

-- ----------------------------------------------------------------------------
-- View 6: Records needing manual review
-- ----------------------------------------------------------------------------
CREATE VIEW v_insurance_firm_needs_review AS
SELECT
    firm_id,
    payer_id,
    name,
    payer_id_new,
    name_new,
    matched_via,
    sync_status,
    sync_details,
    CASE
        WHEN sync_status IN ('PAYER_ID_ONLY', 'NAME_ONLY') THEN 'Mismatch: Review names/IDs'
        WHEN payer_id_fac IS NULL AND payer_id_pro IS NULL AND payer_id_elig IS NULL THEN
            'Incomplete: All payer IDs missing'
        WHEN payer_id_new IS NULL THEN 'Missing: No payer_id_new assigned'
        WHEN name_new IS NULL THEN 'Missing: No name_new assigned'
        ELSE 'Other: Review needed'
    END AS review_reason
FROM insurance_firm
WHERE sync_status IN ('PAYER_ID_ONLY', 'NAME_ONLY')
   OR payer_id_fac IS NULL
   OR payer_id_pro IS NULL
   OR payer_id_elig IS NULL
   OR payer_id_new IS NULL
   OR name_new IS NULL
ORDER BY
    CASE sync_status
        WHEN 'PAYER_ID_ONLY' THEN 1
        WHEN 'NAME_ONLY' THEN 2
        ELSE 3
    END,
    name;

-- ----------------------------------------------------------------------------
-- Summary of created views
-- ----------------------------------------------------------------------------
SELECT
    '=== MONITORING VIEWS CREATED ===' AS views_created,
    'v_insurance_firm_mismatches' AS view_1,
    'Records with old ≠ new values (needs review)' AS description_1,
    'v_insurance_firm_incomplete' AS view_2,
    'Records with missing payer IDs (incomplete data)' AS description_2,
    'v_insurance_firm_recent_sync' AS view_3,
    'Last 100 synced records (audit trail)' AS description_3,
    'v_insurance_firm_payer_id_analysis' AS view_4,
    'Detailed payer ID analysis (old vs new)' AS description_4,
    'v_insurance_firm_sync_dashboard' AS view_5,
    'Overall sync statistics dashboard' AS description_5,
    'v_insurance_firm_needs_review' AS view_6,
    'All records needing manual review' AS description_6;

-- ----------------------------------------------------------------------------
-- Sample queries from views
-- ----------------------------------------------------------------------------
SELECT
    '=== SAMPLE: RECORDS NEEDING REVIEW ===' AS sample_view,
    COUNT(*) AS review_count
FROM v_insurance_firm_needs_review;

-- Show top 10 records needing review
SELECT
    firm_id,
    payer_id,
    name,
    review_reason,
    sync_status
FROM v_insurance_firm_needs_review
ORDER BY review_reason, name
LIMIT 10;

-- ----------------------------------------------------------------------------
-- Optional: Migrate to new values (UNCOMMENT TO USE)
-- ----------------------------------------------------------------------------
/*
-- This will update old payer_id and name to new values
-- ONLY RUN THIS AFTER VERIFYING NEW VALUES ARE CORRECT!

SELECT
    '=== MIGRATION PREVIEW ===' AS preview,
    firm_id,
    payer_id AS current_payer_id,
    payer_id_new AS new_payer_id,
    name AS current_name,
    name_new AS new_name,
    review_reason
FROM v_insurance_firm_needs_review
WHERE review_reason IN ('Mismatch: Review names/IDs')
LIMIT 20;

-- Uncomment below to execute migration
UPDATE insurance_firm
SET
    payer_id = payer_id_new,
    name = name_new,
    sync_status = CONCAT('MIGRATED_', sync_status),
    sync_details = CONCAT('Migrated from "', payer_id, '" / "', name, '" to "', payer_id_new, '" / "', name_new, '"'),
    last_synced_at = CURRENT_TIMESTAMP
WHERE (payer_id != payer_id_new OR name != name_new)
  AND sync_status IN ('EXACT_MATCH', 'PAYER_ID_ONLY', 'NAME_ONLY')
  AND payer_id_new IS NOT NULL
  AND name_new IS NOT NULL;
*/

-- ----------------------------------------------------------------------------
-- Final summary
-- ----------------------------------------------------------------------------
SELECT
    '=== SYNC PROCESS COMPLETE ===' AS final_status,
    (SELECT COUNT(*) FROM insurance_firm) AS final_firm_count,
    (SELECT COUNT(*) FROM insurance_firm WHERE sync_status = 'EXACT_MATCH') AS exact_matches,
    (SELECT COUNT(*) FROM insurance_firm WHERE sync_status IN ('PAYER_ID_ONLY', 'NAME_ONLY')) AS needs_review,
    (SELECT COUNT(*) FROM patient_insurance pi LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id WHERE ifirm.firm_id IS NULL) AS orphaned_patients,
    'All monitoring views created' AS views_status,
    'See v_insurance_firm_sync_dashboard for overview' AS dashboard,
    'See v_insurance_firm_needs_review for action items' AS next_actions;

-- ----------------------------------------------------------------------------
-- Success message
-- ----------------------------------------------------------------------------
SELECT
    '╔════════════════════════════════════════════════════════════╗' AS line1,
    '║           ✓ INSURANCE FIRM SYNC COMPLETE                   ║' AS line2,
    '╠════════════════════════════════════════════════════════════╣' AS line3,
    '║  Monitoring views created for ongoing validation           ║' AS line4,
    '║  Run SELECT * FROM v_insurance_firm_sync_dashboard         ║' AS line5,
    '║  Run SELECT * FROM v_insurance_firm_needs_review           ║' AS line6,
    '╚════════════════════════════════════════════════════════════╝' AS line7;
