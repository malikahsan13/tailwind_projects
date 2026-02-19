-- ============================================================================
-- STEP 2.3: PATIENT_INSURANCE IMPACT ANALYSIS
-- ============================================================================
-- Purpose: Check how many patient records will be affected by deletions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Impact Summary
-- ----------------------------------------------------------------------------
SELECT
    '=== PATIENT_INSURANCE IMPACT SUMMARY ===' AS impact_summary,
    COUNT(DISTINCT ifirm.firm_id) AS garbage_firms_with_patients,
    COUNT(*) AS total_patient_records_affected,
    'These patient records will be orphaned if garbage firms are deleted' AS warning
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

-- ----------------------------------------------------------------------------
-- Detailed breakdown of affected patient records
-- ----------------------------------------------------------------------------
SELECT
    '=== AFFECTED PATIENT RECORDS DETAIL ===' AS detail_type,
    ifirm.firm_id,
    ifirm.payer_id AS firm_payer_id,
    ifirm.name AS firm_name,
    COUNT(*) AS patient_count,
    CASE
        WHEN COUNT(*) = 1 THEN '1 patient affected'
        WHEN COUNT(*) BETWEEN 2 AND 10 THEN CONCAT(COUNT(*), ' patients affected')
        ELSE CONCAT(COUNT(*), ' patients affected - HIGH IMPACT')
    END AS impact_level
FROM insurance_firm ifirm
JOIN patient_insurance pi ON ifirm.firm_id = pi.insurance_firm_id
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id_fac IS NULL
  AND if_oa.payer_id_pro IS NULL
  AND if_oa.payer_id_elig IS NULL
GROUP BY ifirm.firm_id, ifirm.payer_id, ifirm.name
ORDER BY patient_count DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- Show sample affected patient records
-- ----------------------------------------------------------------------------
SELECT
    '=== SAMPLE AFFECTED PATIENT RECORDS ===' AS sample_type,
    pi.patient_insurance_id,
    ifirm.firm_id,
    ifirm.payer_id AS firm_payer_id,
    ifirm.name AS firm_name,
    'This firm will be deleted - patient record will be orphaned' AS note
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

-- ----------------------------------------------------------------------------
-- Check if reassignment is possible
-- ----------------------------------------------------------------------------
SELECT
    '=== REASSIGNMENT POSSIBILITY CHECK ===' AS check_type,
    COUNT(DISTINCT ifirm.firm_id) AS firms_can_be_reassigned,
    'Number of garbage firms that could be reassigned to matching OA records' AS note
FROM insurance_firm ifirm
JOIN patient_insurance pi ON ifirm.firm_id = pi.insurance_firm_id
INNER JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id_fac IS NOT NULL
  OR if_oa.payer_id_pro IS NOT NULL
  OR if_oa.payer_id_elig IS NOT NULL;

-- ----------------------------------------------------------------------------
-- Decision matrix
-- ----------------------------------------------------------------------------
SELECT
    '=== DELETION STRATEGY DECISION MATRIX ===' AS decision_title,
    CASE
        WHEN (
            SELECT COUNT(*)
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
        ) = 0 THEN
            '✓ USE OPTION A: Safe deletion (no patient impact)'
        WHEN (
            SELECT COUNT(*)
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
        ) < 10 THEN
            '⚠ USE OPTION A: Safe deletion (low impact - review manually)'
        WHEN (
            SELECT COUNT(DISTINCT ifirm.firm_id)
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
        ) = (
            SELECT COUNT(DISTINCT ifirm.firm_id)
            FROM patient_insurance pi
            JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
            INNER JOIN insurance_firm_oa if_oa
                ON ifirm.payer_id = if_oa.payer_id_fac
                OR ifirm.payer_id = if_oa.payer_id_pro
                OR ifirm.payer_id = if_oa.payer_id_elig
                OR LOWER(ifirm.name) = LOWER(if_oa.name)
        ) THEN
            '⚠ USE OPTION B: Reassign then delete (all can be reassigned)'
        ELSE
            '⚠ USE OPTION B: Reassign + Option A combo (some cannot be reassigned)'
    END AS recommended_strategy;

-- ----------------------------------------------------------------------------
-- Statistics for decision making
-- ----------------------------------------------------------------------------
SELECT
    '=== DECISION STATISTICS ===' AS stats,
    (SELECT COUNT(*)
     FROM patient_insurance pi
     JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
     LEFT JOIN insurance_firm_oa if_oa
         ON ifirm.payer_id = if_oa.payer_id_fac
         OR ifirm.payer_id = if_oa.payer_id_pro
         OR ifirm.payer_id = if_oa.payer_id_elig
         OR LOWER(ifirm.name) = LOWER(if_oa.name)
     WHERE if_oa.payer_id_fac IS NULL
       AND if_oa.payer_id_pro IS NULL
       AND if_oa.payer_id_elig IS NULL) AS total_patient_records_orphaned,

    (SELECT COUNT(DISTINCT ifirm.firm_id)
     FROM patient_insurance pi
     JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
     LEFT JOIN insurance_firm_oa if_oa
         ON ifirm.payer_id = if_oa.payer_id_fac
         OR ifirm.payer_id = if_oa.payer_id_pro
         OR ifirm.payer_id = if_oa.payer_id_elig
         OR LOWER(ifirm.name) = LOWER(if_oa.name)
     WHERE if_oa.payer_id_fac IS NULL
       AND if_oa.payer_id_pro IS NULL
       AND if_oa.payer_id_elig IS NULL) AS unique_firms_orphaned,

    (SELECT COUNT(DISTINCT ifirm.firm_id)
     FROM patient_insurance pi
     JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
     INNER JOIN insurance_firm_oa if_oa
         ON ifirm.payer_id = if_oa.payer_id_fac
         OR ifirm.payer_id = if_oa.payer_id_pro
         OR ifirm.payer_id = if_oa.payer_id_elig
         OR LOWER(ifirm.name) = LOWER(if_oa.name)) AS firms_can_be_reassigned,

    ROUND(
        (SELECT COUNT(DISTINCT ifirm.firm_id)
         FROM patient_insurance pi
         JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
         INNER JOIN insurance_firm_oa if_oa
             ON ifirm.payer_id = if_oa.payer_id_fac
             OR ifirm.payer_id = if_oa.payer_id_pro
             OR ifirm.payer_id = if_oa.payer_id_elig
             OR LOWER(ifirm.name) = LOWER(if_oa.name)) * 100.0 /
        NULLIF((
            SELECT COUNT(DISTINCT ifirm.firm_id)
            FROM patient_insurance pi
            JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
            LEFT JOIN insurance_firm_oa if_oa
                ON ifirm.payer_id = if_oa.payer_id_fac
                OR ifirm.payer_id = if_oa.payer_id_pro
                OR ifirm.payer_id = if_oa.payer_id_elig
                OR LOWER(ifirm.name) = LOWER(if_oa.name)
            WHERE if_oa.payer_id_fac IS NULL
              AND if_oa.payer_id_pro IS NULL
              AND if_oa.payer_id_elig IS NULL), 0),
        2
    ) AS reassignable_percentage;

-- ----------------------------------------------------------------------------
-- Recommended action message
-- ----------------------------------------------------------------------------
SELECT
    '=== NEXT STEPS ===' AS next_steps,
    '1. Review the affected patient records above' AS step1,
    '2. Decide on deletion strategy (Option A, B, or C)' AS step2,
    '3. Edit step3_sync/02_delete_garbage.sql if using Option B or C' AS step3,
    '4. Proceed to STEP 3: Sync Execution' AS step4,
    'See docs/00_START_HERE.md for detailed instructions' AS reference;
