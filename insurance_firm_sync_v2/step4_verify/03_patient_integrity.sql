-- ============================================================================
-- STEP 4.3: PATIENT_INSURANCE INTEGRITY CHECK
-- ============================================================================
-- Purpose: Verify no patient_insurance records were orphaned during sync
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Check for orphaned patient_insurance records
-- ----------------------------------------------------------------------------
SELECT
    '=== ORPHANED PATIENT RECORDS CHECK ===' AS integrity_check,
    COUNT(*) AS orphaned_count,
    CASE
        WHEN COUNT(*) = 0 THEN '✓ NO ORPHANS - All patient records valid'
        WHEN COUNT(*) < 10 THEN '⚠ LOW ORPHAN COUNT - Review needed'
        ELSE '❌ HIGH ORPHAN COUNT - Critical issue'
    END AS status
FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
WHERE ifirm.firm_id IS NULL;

-- ----------------------------------------------------------------------------
-- Show orphaned patient records (if any)
-- ----------------------------------------------------------------------------
SELECT
    '=== ORPHANED PATIENT RECORDS DETAIL ===' AS detail_type,
    pi.patient_insurance_id,
    pi.insurance_firm_id AS missing_firm_id,
    'This firm_id no longer exists in insurance_firm' AS issue
FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
WHERE ifirm.firm_id IS NULL
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Overall patient_insurance health check
-- ----------------------------------------------------------------------------
SELECT
    '=== PATIENT_INSURANCE HEALTH CHECK ===' AS health_check,
    COUNT(*) AS total_patient_records,
    SUM(CASE WHEN ifirm.firm_id IS NOT NULL THEN 1 ELSE 0 END) AS valid_records,
    SUM(CASE WHEN ifirm.firm_id IS NULL THEN 1 ELSE 0 END) AS orphaned_records,
    ROUND(SUM(CASE WHEN ifirm.firm_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS integrity_percentage,
    CASE
        WHEN SUM(CASE WHEN ifirm.firm_id IS NULL THEN 1 ELSE 0 END) = 0 THEN '✓ 100% INTEGRITY'
        WHEN SUM(CASE WHEN ifirm.firm_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) < 1 THEN '✓ >99% INTEGRITY'
        WHEN SUM(CASE WHEN ifirm.firm_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) < 5 THEN '⚠ >95% INTEGRITY'
        ELSE '❌ <95% INTEGRITY - CRITICAL'
    END AS integrity_status
FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id;

-- ----------------------------------------------------------------------------
-- Patient records by firm sync status
-- ----------------------------------------------------------------------------
SELECT
    '=== PATIENT RECORDS BY FIRM SYNC STATUS ===' AS breakdown,
    ifirm.sync_status,
    COUNT(*) AS patient_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM patient_insurance), 2) AS percentage
FROM patient_insurance pi
JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
GROUP BY ifirm.sync_status
ORDER BY patient_count DESC;

-- ----------------------------------------------------------------------------
-- Firms with most patient references
-- ----------------------------------------------------------------------------
SELECT
    '=== TOP 20 FIRMS BY PATIENT COUNT ===' AS top_firms,
    ifirm.firm_id,
    ifirm.payer_id,
    ifirm.name,
    ifirm.sync_status,
    COUNT(*) AS patient_count
FROM insurance_firm ifirm
JOIN patient_insurance pi ON ifirm.firm_id = pi.insurance_firm_id
GROUP BY ifirm.firm_id, ifirm.payer_id, ifirm.name, ifirm.sync_status
ORDER BY patient_count DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Check if patient_insurance references deleted firms
-- ----------------------------------------------------------------------------
SELECT
    '=== REFERENCE INTEGRITY CHECK ===' AS ref_check,
    COUNT(DISTINCT pi.insurance_firm_id) AS unique_firms_referenced,
    (SELECT COUNT(DISTINCT firm_id) FROM insurance_firm) AS total_firms_in_table,
    CASE
        WHEN COUNT(DISTINCT pi.insurance_firm_id) = (SELECT COUNT(DISTINCT firm_id) FROM insurance_firm) THEN
            '✓ ALL REFERENCED FIRMS EXIST'
        ELSE
            CONCAT('⚠ SOME REFERENCED FIRMS MISSING: ',
                   (SELECT COUNT(DISTINCT firm_id) FROM insurance_firm) -
                   COUNT(DISTINCT pi.insurance_firm_id),
                   ' firms not referenced')
    END AS status
FROM patient_insurance pi
INNER JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id;

-- ----------------------------------------------------------------------------
-- Potential issues: Firms with no patient references (could be garbage)
-- ----------------------------------------------------------------------------
SELECT
    '=== FIRMS WITH NO PATIENT REFERENCES ===' AS no_refs,
    COUNT(*) AS firm_count,
    CASE
        WHEN COUNT(*) = 0 THEN '✓ ALL FIRMS HAVE PATIENT REFERENCES'
        WHEN COUNT(*) < (SELECT COUNT(*) FROM insurance_firm) * 0.1 THEN '⚠ <10% firms unused'
        ELSE '⚠ MANY FIRMS UNUSED - Review if these are needed'
    END AS status
FROM insurance_firm ifirm
LEFT JOIN patient_insurance pi ON ifirm.firm_id = pi.insurance_firm_id
WHERE pi.insurance_firm_id IS NULL;

-- Show sample of unused firms
SELECT
    firm_id,
    payer_id,
    name,
    sync_status
FROM insurance_firm ifirm
LEFT JOIN patient_insurance pi ON ifirm.firm_id = pi.insurance_firm_id
WHERE pi.insurance_firm_id IS NULL
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Summary and recommendations
-- ----------------------------------------------------------------------------
SELECT
    '=== INTEGRITY SUMMARY ===' AS summary_title,
    CASE
        WHEN (SELECT COUNT(*) FROM patient_insurance pi LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id WHERE ifirm.firm_id IS NULL) = 0 THEN
            '✓ EXCELLENT: No orphaned patient records'
        ELSE
            CONCAT('⚠ ACTION NEEDED: ',
                   (SELECT COUNT(*) FROM patient_insurance pi LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id WHERE ifirm.firm_id IS NULL),
                   ' orphaned patient records')
    END AS orphan_status,

    CASE
        WHEN (SELECT COUNT(*) FROM insurance_firm WHERE sync_status = 'EXACT_MATCH') * 100.0 / (SELECT COUNT(*) FROM insurance_firm) >= 70 THEN
            '✓ EXCELLENT: Most firms have exact matches'
        ELSE
            '⚠ REVIEW: Some firms need manual review'
    END AS match_quality,

    'Run step4_verify/04_cleanup.sql to create monitoring views' AS next_step;
