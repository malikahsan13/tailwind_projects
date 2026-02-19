# Custom Cleanup Guide - Usage-Based Strategy

## 📋 Your Requirements Summary

1. **Firms with submitted claims** → Match with OA, update with OA data
2. **Firms in patient_insurance but no claims** → Same as above
3. **Firms NOT in patient_insurance** → Drop and reload from OA

---

## 🚀 Quick Start

### Step 1: Validate Current State
```bash
mysql -u root -p your_db < step5_custom_cleanup/01_validate_requirements.sql
```

**Review the output carefully:**
- Check firms in claims and their match status
- Check firms in patient_insurance only
- Check firms not used (will be deleted)
- Look for any NO_MATCH firms in claims (critical!)

### Step 2: Execute Cleanup
```bash
mysql -u root -p your_db < step5_custom_cleanup/02_execute_cleanup.sql
```

---

## 📊 What Each Script Does

### 01_validate_requirements.sql

**Analysis 1: Current State**
- Shows overall sync status after your update matching phase

**Analysis 2: Firms in Claims (Requirement 1)**
- Count of unique firms in `pms_claims`
- Details of each firm (using your query)
- Match status breakdown for claims firms

**Analysis 3: Firms in Patient Insurance Only (Requirement 2)**
- Count of firms with patients but no claims
- Details using your query
- Match status breakdown

**Analysis 4: Firms Not Used (Requirement 3)**
- Count of firms not in `patient_insurance`
- These will be deleted and reloaded

**Analysis 5: Cross-Reference Summary**
- Venn diagram: Claims only, Patients only, Unused, Total

**Analysis 6: Match Quality**
- Compares match quality across all 3 categories

**Analysis 7: Potential Issues**
- **CRITICAL:** Firms in claims with NO_MATCH status
- Shows claims count and patient count for each

---

### 02_execute_cleanup.sql

**Phase 1: Update Active Firms (Requirements 1 & 2)**
- Updates firms in `pms_claims` OR `patient_insurance`
- Sets `sync_status = 'ACTIVE_EXACT_MATCH'`, `'ACTIVE_PAYER_ID_ONLY'`, etc.
- All OA data populated

**Phase 2: Delete Unused Firms (Requirement 3)**
- Deletes firms NOT in `patient_insurance`
- These are safe to delete (no references)

**Phase 3: Reload from OA**
- Inserts missing records from `insurance_firm_oa`
- Sets `sync_status = 'RELOADED_FROM_OA'`

**Final Verification:**
- Row counts
- Patient integrity check
- Claims integrity check
- Overall success status

---

## 🔍 Your Helper Queries

The scripts include your queries and expand on them:

### Your Query 1: Firms in Claims
```sql
SELECT DISTINCT(firm_id), payer_id, `name`, sync_status, `sync_details`, `matched_via`
FROM insurance_firm
WHERE firm_id IN (SELECT insurance_firm_id FROM pms_claims)
```

### Your Query 2: Firms in Patient Insurance
```sql
SELECT DISTINCT(firm_id), payer_id, `name`, sync_status, `sync_details`, `matched_via`
FROM insurance_firm
WHERE firm_id IN (SELECT `insurance_firm_id` FROM patient_insurance)
```

### Enhanced Version (Included in scripts)
```sql
-- Shows claims count and patient count together
SELECT
    firm_id,
    payer_id,
    `name`,
    sync_status,
    matched_via,
    (SELECT COUNT(*) FROM patient_insurance WHERE insurance_firm_id = ifirm.firm_id) AS patient_count,
    (SELECT COUNT(*) FROM pms_claims WHERE insurance_firm_id = ifirm.firm_id) AS claims_count
FROM insurance_firm ifirm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance)
ORDER BY claims_count DESC, patient_count DESC;
```

---

## ⚠️ Critical Checks Before Execution

### 1. Check for Claims Firms with NO_MATCH
```sql
SELECT
    firm_id,
    payer_id,
    `name`,
    (SELECT COUNT(*) FROM pms_claims WHERE insurance_firm_id = ifirm.firm_id) AS claims_count
FROM insurance_firm ifirm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM pms_claims)
  AND sync_status = 'NO_MATCH'
ORDER BY claims_count DESC;
```

**If count > 0:** These firms have submitted claims but don't match OA!
- **Don't delete them** (they're used in claims)
- Manual review needed
- May need to add them to OA

### 2. Verify Row Counts
```sql
SELECT
    (SELECT COUNT(*) FROM insurance_firm) AS current_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) AS oa_count;
```

After cleanup, these should be close (may differ by unused firms count)

---

## ✅ Expected Results After Execution

### Before Cleanup
```
insurance_firm: 1000 records
├── Used in claims: 300
├── Patient insurance only: 200
└── Not used: 500
```

### After Cleanup
```
insurance_firm: ~900 records
├── ACTIVE_* (claims + patients): 500 updated
└── RELOADED_FROM_OA: ~400 inserted

Status breakdown:
├── ACTIVE_EXACT_MATCH: ~350
├── ACTIVE_PAYER_ID_ONLY: ~100
├── ACTIVE_NAME_ONLY: ~50
└── RELOADED_FROM_OA: ~400
```

---

## 🔧 Troubleshooting

### Issue: Orphaned claims after cleanup
**Cause:** Firms in claims but no OA match were deleted

**Solution:**
```sql
-- Find orphaned claims
SELECT pc.*, ifirm.payer_id
FROM pms_claims pc
LEFT JOIN insurance_firm ifirm ON pc.insurance_firm_id = ifirm.firm_id
WHERE pc.insurance_firm_id IS NOT NULL
  AND ifirm.firm_id IS NULL;

-- Re-insert missing firms (manual review needed)
```

### Issue: Too many firms deleted
**Cause:** Logic error in patient_insurance check

**Solution:**
```sql
-- Verify patient_insurance references
SELECT COUNT(DISTINCT insurance_firm_id)
FROM patient_insurance
WHERE insurance_firm_id IS NOT NULL;

-- Should match your expected count
```

---

## 📊 Verification Queries

### After Execution - Check Results

```sql
-- 1. Overall status
SELECT sync_status, COUNT(*)
FROM insurance_firm
GROUP BY sync_status;

-- 2. Active firms breakdown
SELECT
    CASE
        WHEN sync_status LIKE 'ACTIVE_%' THEN SUBSTRING(sync_status, 8)
        ELSE sync_status
    END AS status,
    COUNT(*)
FROM insurance_firm
WHERE firm_id IN (SELECT DISTINCT insurance_firm_id FROM patient_insurance)
GROUP BY status;

-- 3. Verify no orphans
SELECT
    COUNT(*) AS orphaned_patients
FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
WHERE ifirm.firm_id IS NULL;  -- Should be 0

-- 4. Match quality
SELECT
    matched_via,
    COUNT(*) AS count
FROM insurance_firm
WHERE sync_status LIKE 'ACTIVE_%'
GROUP BY matched_via;
```

---

## 🎯 Key Differences from Original Scripts

| Aspect | Original Scripts | Custom Scripts |
|--------|-----------------|----------------|
| Deletion criteria | NO_MATCH status | NOT in patient_insurance |
| Update target | All matching records | Only active firms (claims + patients) |
| Sync status | EXACT_MATCH, etc. | ACTIVE_EXACT_MATCH, etc. |
| Reload source | All OA records | Only OA records not in firm |
| Patient safety | Checks before delete | Checks before + after |

---

## 📞 Quick Summary

1. **Run validation script** → Review all outputs
2. **Check for NO_MATCH in claims** → Manual review if any
3. **Run cleanup script** → Updates active firms, deletes unused, reloads
4. **Verify** → Zero orphans, proper status distribution

**Files Location:** `insurance_firm_sync_v2/step5_custom_cleanup/`
- `01_validate_requirements.sql` - Run first
- `02_execute_cleanup.sql` - Run after review
