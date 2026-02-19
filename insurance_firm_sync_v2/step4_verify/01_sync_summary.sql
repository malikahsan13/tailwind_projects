-- ============================================================================
-- STEP 4.1: SYNC SUMMARY
-- ============================================================================
-- Purpose: Overall summary of sync results
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Overall sync status distribution
-- ----------------------------------------------------------------------------
SELECT
    '=== SYNC STATUS DISTRIBUTION ===' AS summary_title,
    sync_status,
    matched_via,
    COUNT(*) AS record_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
WHERE sync_status IS NOT NULL
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
-- Aggregated summary
-- ----------------------------------------------------------------------------
SELECT
    '=== AGGREGATED SUMMARY ===' AS summary_title,
    'EXACT_MATCH' AS exact_match_status,
    SUM(CASE WHEN sync_status = 'EXACT_MATCH' THEN 1 ELSE 0 END) AS exact_count,
    ROUND(SUM(CASE WHEN sync_status = 'EXACT_MATCH' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS exact_percentage,
    SUM(CASE WHEN sync_status IN ('PAYER_ID_ONLY', 'NAME_ONLY') THEN 1 ELSE 0 END) AS needs_review_count,
    ROUND(SUM(CASE WHEN sync_status IN ('PAYER_ID_ONLY', 'NAME_ONLY') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS needs_review_percentage,
    SUM(CASE WHEN sync_status = 'NEW_FROM_OA' THEN 1 ELSE 0 END) AS new_count,
    ROUND(SUM(CASE WHEN sync_status = 'NEW_FROM_OA' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS new_percentage,
    COUNT(*) AS total_records
FROM insurance_firm
WHERE sync_status IS NOT NULL;

-- ----------------------------------------------------------------------------
-- matched_via breakdown
-- ----------------------------------------------------------------------------
SELECT
    '=== MATCHED_VIA BREAKDOWN ===' AS breakdown_title,
    matched_via,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm WHERE sync_status IS NOT NULL), 2) AS percentage,
    CASE
        WHEN matched_via = 'fac' THEN 'Matched on facility payer ID'
        WHEN matched_via = 'pro' THEN 'Matched on professional payer ID'
        WHEN matched_via = 'elig' THEN 'Matched on eligibility payer ID'
        WHEN matched_via = 'name' THEN 'Matched on name only'
        ELSE 'Unknown'
    END AS description
FROM insurance_firm
WHERE sync_status IS NOT NULL
GROUP BY matched_via
ORDER BY count DESC;

-- ----------------------------------------------------------------------------
-- Row count comparison
-- ----------------------------------------------------------------------------
SELECT
    '=== ROW COUNT COMPARISON ===' AS comparison_title,
    (SELECT COUNT(*) FROM insurance_firm) AS final_firm_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) AS oa_count,
    ABS((SELECT COUNT(*) FROM insurance_firm) - (SELECT COUNT(*) FROM insurance_firm_oa)) AS difference,
    CASE
        WHEN (SELECT COUNT(*) FROM insurance_firm) = (SELECT COUNT(*) FROM insurance_firm_oa) THEN
            '✓ Perfect match'
        WHEN ABS((SELECT COUNT(*) FROM insurance_firm) - (SELECT COUNT(*) FROM insurance_firm_oa)) <= 5 THEN
            '⚠ Small difference (acceptable)'
        ELSE
            '⚠ Significant difference - review'
    END AS status;

-- ----------------------------------------------------------------------------
-- Records by sync status category
-- ----------------------------------------------------------------------------
SELECT
    '=== SYNC STATUS CATEGORIES ===' AS categories,
    'Perfect Matches (EXACT)' AS category,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
WHERE sync_status = 'EXACT_MATCH'

UNION ALL

SELECT
    '=== SYNC STATUS CATEGORIES ===' AS categories,
    'Needs Review (PAYER_ID_ONLY)' AS category,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
WHERE sync_status = 'PAYER_ID_ONLY'

UNION ALL

SELECT
    '=== SYNC STATUS CATEGORIES ===' AS categories,
    'Needs Review (NAME_ONLY)' AS category,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
WHERE sync_status = 'NAME_ONLY'

UNION ALL

SELECT
    '=== SYNC STATUS CATEGORIES ===' AS categories,
    'New Records (NEW_FROM_OA)' AS category,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
WHERE sync_status = 'NEW_FROM_OA'

UNION ALL

SELECT
    '=== SYNC STATUS CATEGORIES ===' AS categories,
    'Other/Unknown' AS category,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
WHERE sync_status IS NULL
   OR sync_status NOT IN ('EXACT_MATCH', 'PAYER_ID_ONLY', 'NAME_ONLY', 'NEW_FROM_OA');

-- ----------------------------------------------------------------------------
-- Success assessment
-- ----------------------------------------------------------------------------
SELECT
    '=== SUCCESS ASSESSMENT ===' AS assessment,
    CASE
        WHEN (SELECT COUNT(*) FROM insurance_firm WHERE sync_status = 'EXACT_MATCH') * 100.0 / (SELECT COUNT(*) FROM insurance_firm) >= 80 THEN
            '✓ EXCELLENT: >80% exact matches'
        WHEN (SELECT COUNT(*) FROM insurance_firm WHERE sync_status = 'EXACT_MATCH') * 100.0 / (SELECT COUNT(*) FROM insurance_firm) >= 60 THEN
            '✓ GOOD: >60% exact matches'
        WHEN (SELECT COUNT(*) FROM insurance_firm WHERE sync_status = 'EXACT_MATCH') * 100.0 / (SELECT COUNT(*) FROM insurance_firm) >= 40 THEN
            '⚠ FAIR: >40% exact matches - some manual cleanup needed'
        ELSE
            '⚠ POOR: <40% exact matches - significant manual cleanup needed'
    END AS exact_match_quality,

    CASE
        WHEN (SELECT COUNT(*) FROM insurance_firm WHERE sync_status IN ('PAYER_ID_ONLY', 'NAME_ONLY')) * 100.0 / (SELECT COUNT(*) FROM insurance_firm) <= 10 THEN
            '✓ EXCELLENT: <10% need review'
        WHEN (SELECT COUNT(*) FROM insurance_firm WHERE sync_status IN ('PAYER_ID_ONLY', 'NAME_ONLY')) * 100.0 / (SELECT COUNT(*) FROM insurance_firm) <= 20 THEN
            '✓ GOOD: <20% need review'
        ELSE
            '⚠ ATTENTION: >20% need review'
    END AS review_workload,

    CASE
        WHEN ABS((SELECT COUNT(*) FROM insurance_firm) - (SELECT COUNT(*) FROM insurance_firm_oa)) = 0 THEN
            '✓ EXCELLENT: Row counts match perfectly'
        WHEN ABS((SELECT COUNT(*) FROM insurance_firm) - (SELECT COUNT(*) FROM insurance_firm_oa)) <= 5 THEN
            '✓ GOOD: Small difference acceptable'
        ELSE
            '⚠ REVIEW: Row count difference needs investigation'
    END AS data_completeness;

-- ----------------------------------------------------------------------------
-- Sample records from each status
-- ----------------------------------------------------------------------------
SELECT
    '=== SAMPLE: EXACT MATCHES ===' AS sample_type,
    firm_id,
    payer_id AS old_payer_id,
    name AS old_name,
    payer_id_new,
    name_new,
    matched_via
FROM insurance_firm
WHERE sync_status = 'EXACT_MATCH'
LIMIT 5;

SELECT
    '=== SAMPLE: PAYER_ID_ONLY ===' AS sample_type,
    firm_id,
    payer_id AS old_payer_id,
    name AS old_name,
    payer_id_new,
    name_new,
    matched_via
FROM insurance_firm
WHERE sync_status = 'PAYER_ID_ONLY'
LIMIT 5;

SELECT
    '=== SAMPLE: NAME_ONLY ===' AS sample_type,
    firm_id,
    payer_id AS old_payer_id,
    name AS old_name,
    payer_id_new,
    name_new,
    matched_via
FROM insurance_firm
WHERE sync_status = 'NAME_ONLY'
LIMIT 5;

SELECT
    '=== SAMPLE: NEW FROM OA ===' AS sample_type,
    firm_id,
    payer_id,
    name,
    matched_via,
    sync_details
FROM insurance_firm
WHERE sync_status = 'NEW_FROM_OA'
LIMIT 5;
