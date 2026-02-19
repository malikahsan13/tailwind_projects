-- ============================================================================
-- CUSTOM VALIDATION - Patient and Claims Usage Based Cleanup
-- ============================================================================
-- Purpose: Validate and cleanup insurance_firm based on actual usage
-- Requirements:
-- 1. Firms in claims → Match with OA, update with OA data
-- 2. Firms in patient_insurance but NOT in claims → Match with OA, update
-- 3. Firms NOT in patient_insurance → Drop and reload from OA
-- ============================================================================

-- ============================================================================
-- ANALYSIS 1: Current State After Update Matching
-- ============================================================================

SELECT
    '=== CURRENT STATE AFTER UPDATE MATCHING ===' AS analysis;

-- Overall sync status
SELECT
    sync_status,
    matched_via,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
GROUP BY sync_status, matched_via
ORDER BY count DESC;

-- ============================================================================
-- ANALYSIS 2: Firms Used in Claims (Requirement 1)
-- ============================================================================

SELECT
    '=== REQUIREMENT 1: FIRMS IN CLAIMS ===' AS requirement;

-- Count of unique firms in claims
SELECT
    COUNT(DISTINCT insurance_firm_id) AS unique_firms_in_claims,
    (SELECT COUNT(*) FROM pms_claims WHERE insurance_firm_id IS NOT NULL) AS total_claims_with_firm,
    (SELECT COUNT(*) FROM pms_claims) AS total_claims;

-- Details of firms in claims (your query)
SELECT
    firm_id,
    payer_id,
    `name`,
    sync_status,
    sync_details,
    matched_via
FROM insurance_firm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL)
ORDER BY `name`;

-- Check claims firms match status
SELECT
    'Claims Firms Match Status' AS check_type,
    sync_status,
    matched_via,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (
        SELECT COUNT(DISTINCT insurance_firm_id)
        FROM pms_claims
        WHERE insurance_firm_id IS NOT NULL
    ), 2) AS percentage
FROM insurance_firm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL)
GROUP BY sync_status, matched_via
ORDER BY count DESC;

-- ============================================================================
-- ANALYSIS 3: Firms in Patient Insurance but NOT in Claims (Requirement 2)
-- ============================================================================

SELECT
    '=== REQUIREMENT 2: FIRMS IN PATIENT_INSURANCE BUT NOT IN CLAIMS ===' AS requirement;

-- Count of firms assigned to patients but no claims
SELECT
    COUNT(DISTINCT pi.insurance_firm_id) AS firms_in_patient_insurance_only,
    COUNT(DISTINCT pc.insurance_firm_id) AS firms_in_claims,
    COUNT(DISTINCT pi.insurance_firm_id) - COUNT(DISTINCT pc.insurance_firm_id) AS firms_without_claims
FROM patient_insurance pi
LEFT JOIN pms_claims pc ON pi.insurance_firm_id = pc.insurance_firm_id
WHERE pi.insurance_firm_id IS NOT NULL;

-- Details of firms in patient_insurance only (your query)
SELECT
    firm_id,
    payer_id,
    `name`,
    sync_status,
    sync_details,
    matched_via,
    (SELECT COUNT(*) FROM patient_insurance WHERE insurance_firm_id = ifirm.firm_id) AS patient_count,
    (SELECT COUNT(*) FROM pms_claims WHERE insurance_firm_id = ifirm.firm_id) AS claims_count
FROM insurance_firm ifirm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance)
  AND firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL)
ORDER BY `name`;

-- Check patient-only firms match status
SELECT
    'Patient-Only Firms Match Status' AS check_type,
    sync_status,
    matched_via,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (
        SELECT COUNT(*)
        FROM insurance_firm
        WHERE firm_id IN (
            SELECT DISTINCT insurance_firm_id FROM patient_insurance
            WHERE insurance_firm_id IS NOT NULL
        )
        AND firm_id NOT IN (
            SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL
        )
    ), 2) AS percentage
FROM insurance_firm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance)
  AND firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL)
GROUP BY sync_status, matched_via
ORDER BY count DESC;

-- ============================================================================
-- ANALYSIS 4: Firms NOT in Patient Insurance (Requirement 3)
-- ============================================================================

SELECT
    '=== REQUIREMENT 3: FIRMS NOT IN PATIENT_INSURANCE (DROP & RELOAD) ===' AS requirement;

-- Count of firms not assigned to any patient
SELECT
    COUNT(*) AS firms_not_in_patient_insurance,
    (SELECT COUNT(*) FROM insurance_firm) AS total_firms,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
WHERE firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL);

-- Details of firms to drop and reload
SELECT
    firm_id,
    payer_id,
    `name`,
    sync_status,
    matched_via,
    CASE
        WHEN sync_status IN ('EXACT_MATCH', 'PAYER_ID_ONLY', 'NAME_ONLY') THEN 'Has OA match'
        ELSE 'No OA match'
    END AS oa_match_status
FROM insurance_firm
WHERE firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL)
ORDER BY `name`;

-- ============================================================================
-- ANALYSIS 5: Cross-Reference Summary
-- ============================================================================

SELECT
    '=== CROSS-REFERENCE SUMMARY ===' AS summary_title;

-- Venn diagram summary
SELECT
    'Firms with Claims' AS category,
    COUNT(DISTINCT insurance_firm_id) AS count
FROM pms_claims
WHERE insurance_firm_id IS NOT NULL

UNION ALL

SELECT
    'Firms in Patient Insurance (no claims)',
    COUNT(DISTINCT pi.insurance_firm_id)
FROM patient_insurance pi
LEFT JOIN pms_claims pc ON pi.insurance_firm_id = pc.insurance_firm_id
WHERE pi.insurance_firm_id IS NOT NULL
  AND pc.insurance_firm_id IS NULL

UNION ALL

SELECT
    'Firms not used at all',
    COUNT(*)
FROM insurance_firm
WHERE firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL)

UNION ALL

SELECT
    'Total firms in database',
    COUNT(*)
FROM insurance_firm;

-- ============================================================================
-- ANALYSIS 6: Match Quality Assessment
-- ============================================================================

SELECT
    '=== MATCH QUALITY ASSESSMENT ===' AS assessment;

-- For firms with claims
SELECT
    'Firms with Claims' AS firm_category,
    sync_status,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM insurance_firm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL)
GROUP BY sync_status

UNION ALL

-- For firms with patients only
SELECT
    'Firms with Patients Only',
    sync_status,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM insurance_firm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance)
  AND firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL)
GROUP BY sync_status

UNION ALL

-- For unused firms
SELECT
    'Firms Not Used',
    sync_status,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM insurance_firm
WHERE firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL)
GROUP BY sync_status;

-- ============================================================================
-- ANALYSIS 7: Potential Issues
-- ============================================================================

SELECT
    '=== POTENTIAL ISSUES ===' AS issues_title;

-- Firms in claims but NO_MATCH status (concerning!)
SELECT
    'Claims Firms with NO_MATCH' AS issue_type,
    COUNT(*) AS count,
    '⚠️ CRITICAL: These firms have claims but no OA match!' AS note
FROM insurance_firm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL)
  AND sync_status = 'NO_MATCH';

-- Show these problematic firms
SELECT
    firm_id,
    payer_id,
    `name`,
    sync_status,
    (SELECT COUNT(*) FROM pms_claims WHERE insurance_firm_id = ifirm.firm_id) AS claims_count,
    (SELECT COUNT(*) FROM patient_insurance WHERE insurance_firm_id = ifirm.firm_id) AS patient_count
FROM insurance_firm ifirm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL)
  AND sync_status = 'NO_MATCH'
ORDER BY claims_count DESC;

-- ============================================================================
-- SUMMARY FOR DECISION MAKING
-- ============================================================================

SELECT
    '=== EXECUTION SUMMARY ===' AS summary;

SELECT
    '1. Firms in Claims' AS step1,
    COUNT(DISTINCT insurance_firm_id) AS firms_count,
    'Keep and update with OA data' AS action,
    'Critical - These have submitted claims' AS priority
FROM pms_claims
WHERE insurance_firm_id IS NOT NULL

UNION ALL

SELECT
    '2. Firms in Patient Insurance only',
    COUNT(DISTINCT insurance_firm_id),
    'Keep and update with OA data',
    'Important - Patients mapped but no claims yet'
FROM patient_insurance
WHERE insurance_firm_id IS NOT NULL
  AND insurance_firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM pms_claims WHERE insurance_firm_id IS NOT NULL)

UNION ALL

SELECT
    '3. Firms not used',
    COUNT(*),
    'DROP and reload from OA',
    'Safe - Not referenced anywhere'
FROM insurance_firm
WHERE firm_id NOT IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance WHERE insurance_firm_id IS NOT NULL);

SELECT
    'Review results above, then run step5_custom_cleanup/02_execute_cleanup.sql' AS next_step;
