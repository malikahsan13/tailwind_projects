# Revised Insurance Firm Sync - Implementation Guide

## 🔄 What Changed from Original Approach?

### Original Script (❌ Not Suitable)
- Updated existing `payer_id` and `name` columns
- No handling of garbage records
- No insertion of missing records from OA

### Revised Script (✅ Your Requirements)
- ➕ **NEW columns**: `payer_id_new`, `name_new` (preserves old values!)
- 🗑️ **Deletes** garbage records (not in OA)
- ➕ **Inserts** new records from OA
- ✅ **Keeps** old `payer_id` and `name` untouched
- 📊 **Tracks** all changes with `sync_status`

---

## 📋 Required New Columns

Before running the sync script, ensure these columns exist:

```sql
ALTER TABLE `insurance_firm`
ADD COLUMN `payer_id_new` VARCHAR(200) NULL AFTER `payer_id`,
ADD COLUMN `name_new` VARCHAR(255) NULL AFTER `name`,
ADD COLUMN `sync_status` VARCHAR(50) NULL AFTER `wc_auto_elig`,
ADD COLUMN `sync_details` TEXT NULL AFTER `sync_status`,
ADD COLUMN `last_synced_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP AFTER `sync_details`;
```

---

## 🚀 Step-by-Step Execution

### **Step 1: Pre-Flight Check** (5 minutes)
📁 File: `revised_pre_flight_check.sql`

```bash
mysql < revised_pre_flight_check.sql
```

**What it does:**
- Compares row counts between `insurance_firm` and `insurance_firm_oa`
- Predicts match outcomes (EXACT vs PAYER_ID_ONLY vs NAME_ONLY vs NO_MATCH)
- **Critical**: Shows how many records will be DELETED (garbage)
- **Critical**: Shows if patient_insurance will be AFFECTED by deletions
- Shows how many NEW records will be INSERTED from OA

**Key outputs to review:**
```
✅ MATCH OUTCOMES: Should show mostly EXACT_MATCH
⚠️ GARBAGE RECORDS: Count of records to be deleted
⚠️ PATIENT IMPACT: How many patient_insurance records will be orphaned
✅ NEW RECORDS: Count of records to insert from OA
```

**Decision point:**
- If **patient records will be orphaned** → Choose deletion strategy (see Step 2)
- If **garbage count is high** → Review if these are truly garbage
- If **new records count is high** → Verify OA has correct data

---

### **Step 2: Main Sync Script** (10-30 minutes depending on data size)
📁 File: `revised_sync_script.sql`

**Phase Structure:**

#### **Phase 1: Update Existing Matching Records**
- Updates records that match between `insurance_firm` and `insurance_firm_oa`
- Sets `payer_id_new` and `name_new` to OA values
- Updates all 3 payer IDs (fac, pro, elig)
- Updates all flag columns (non_par, secondary_ins, attachment, wc_auto)
- Sets `sync_status` to: `EXACT_MATCH`, `PAYER_ID_ONLY`, or `NAME_ONLY`
- ✅ **Does NOT modify** original `payer_id` and `name`

#### **Phase 2: Delete Garbage Records**
**⚠️ CRITICAL: Choose ONE option based on patient_insurance impact:**

**Option A: Safe** (Recommended first pass)
```sql
-- Deletes ONLY garbage records with NO patient_insurance references
-- Preserves data integrity
-- Run this FIRST
```
- ✅ Won't break any patient_insurance records
- ⚠️ May leave some garbage records if they have patient references

**Option B: Reassign** (If patient records exist)
```sql
-- Reassigns patient_insurance to matching OA records
-- Then deletes garbage records
-- Use AFTER reviewing reassignment mapping
```
- ✅ Handles patient references
- ⚠️ Requires manual verification of reassignments

**Option C: Delete All** (Dangerous)
```sql
-- Deletes ALL garbage records
-- Will orphan patient_insurance records
-- Handle orphans in Step 3
```
- ⚠️ **Only use** if you're certain about cleanup strategy

#### **Phase 3: Insert New Records from OA**
- Inserts records that exist in `insurance_firm_oa` but NOT in `insurance_firm`
- All columns populated from OA
- Sets `sync_status` to `NEW_FROM_OA`

**Execution:**
```bash
mysql < revised_sync_script.sql
```

**What to monitor:**
- Records updated in Phase 1
- Records deleted in Phase 2
- Records inserted in Phase 3
- Any errors or warnings

---

### **Step 3: Post-Sync Cleanup** (10 minutes)
📁 File: `post_sync_cleanup.sql`

```bash
mysql < post_sync_cleanup.sql
```

**What it does:**

1. **Handles orphaned patient_insurance records**
   - Finds all orphaned records
   - Offers 3 options: reassign, set to NULL, or delete

2. **Cleans up mismatches**
   - Identifies records where old ≠ new values
   - Provides option to migrate to new values

3. **Syncs remaining NULL values**
   - Attempts to fill in any missing payer IDs
   - Updates incomplete records

4. **Final verification**
   - Sync status distribution
   - Data completeness check
   - Patient insurance integrity check

5. **Creates monitoring views**
   - `v_insurance_firm_mismatches` - Records with old≠new values
   - `v_insurance_firm_incomplete` - Records with missing data
   - `v_insurance_firm_recent_sync` - Recently synced records

---

## 📊 Column Mapping After Sync

| Column | Description | Source |
|--------|-------------|--------|
| `payer_id` | **OLD** payer ID (preserved) | Original insurance_firm |
| `name` | **OLD** name (preserved) | Original insurance_firm |
| `payer_id_new` | **NEW/CORRECT** payer ID | insurance_firm_oa |
| `name_new` | **NEW/CORRECT** name | insurance_firm_oa |
| `payer_id_fac` | Facility payer ID | insurance_firm_oa |
| `payer_id_pro` | Professional payer ID | insurance_firm_oa |
| `payer_id_elig` | Eligibility payer ID | insurance_firm_oa |
| `payer_id_*_enrollment` | Enrollment status | insurance_firm_oa |
| `non_par_*` | Non-participating flags | insurance_firm_oa |
| `secondary_ins_*` | Secondary insurance flags | insurance_firm_oa |
| `attachment_*` | Attachment required flags | insurance_firm_oa |
| `wc_auto_*` | Workers comp auto flags | insurance_firm_oa |
| `sync_status` | Match/cleanup status | System generated |
| `sync_details` | Detailed description | System generated |
| `last_synced_at` | Last sync timestamp | System generated |

---

## 🎯 Sync Status Values

| Status | Meaning | Action |
|--------|---------|--------|
| `EXACT_MATCH` | Old & new values identical | ✅ Good - can migrate to new |
| `PAYER_ID_ONLY` | Payer IDs match, names differ | ⚠️ Review - which name is correct? |
| `NAME_ONLY` | Names match, payer IDs differ | ⚠️ Review - which payer_id is correct? |
| `NO_MATCH` | No correlation in OA | ❌ Deleted as garbage |
| `NEW_FROM_OA` | New record inserted | ✅ Good |
| `SYNCED_LATE` | Filled in during cleanup | ✅ Good |
| `MIGRATED_*` | Migrated to new values | ✅ Final state |

---

## ⚠️ Critical Decision Points

### Decision 1: Garbage Record Deletion Strategy

**Check patient_insurance impact first:**
```sql
SELECT COUNT(*) FROM patient_insurance pi
JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
LEFT JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id
    OR LOWER(ifirm.name) = LOWER(if_oa.name)
WHERE if_oa.payer_id IS NULL;
```

**If count > 0:**
- Use **Option A** (Safe deletion) + manual reassignment
- Or use **Option B** (Auto reassign) after verification
- Document affected patient records

**If count = 0:**
- Use **Option A** (Safe deletion)
- No patient impact

---

### Decision 2: Migrate to New Values?

After sync, you'll have both old and new values. Should you migrate?

**Reasons to migrate:**
- ✅ OA is source of truth
- ✅ Simplifies future queries
- ✅ Consistent data across system

**Reasons to keep both:**
- ⚠️ Need audit trail
- ⚠️ Application compatibility
- ⚠️ Gradual migration strategy

**If migrating, do it in stages:**
1. Update application to use `payer_id_new` and `name_new`
2. Test thoroughly
3. Then migrate old columns to new values
4. Drop old columns after verification

---

## ✅ Verification Checklist

After completing all steps, verify:

- [ ] Row count matches `insurance_firm_oa` (or close, after removing garbage)
- [ ] All `payer_id_fac`, `payer_id_pro`, `payer_id_elig` are populated
- [ ] No orphaned `patient_insurance` records
- [ ] `sync_status` is set for all records
- [ ] `last_synced_at` is populated
- [ ] Garbage records removed
- [ ] New records from OA inserted
- [ ] Mismatch records reviewed and documented
- [ ] Application still works (if using old columns)

---

## 🔍 Sample Queries for Verification

```sql
-- Check row counts match
SELECT
    (SELECT COUNT(*) FROM insurance_firm) AS firm_count,
    (SELECT COUNT(*) FROM insurance_firm_oa) AS oa_count;

-- Check data completeness
SELECT
    SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) AS fac_count,
    SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) AS pro_count,
    SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) AS elig_count,
    COUNT(*) AS total
FROM insurance_firm;

-- Check sync status distribution
SELECT sync_status, COUNT(*)
FROM insurance_firm
GROUP BY sync_status;

-- Check for orphans
SELECT COUNT(*)
FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
WHERE ifirm.firm_id IS NULL;

-- View mismatches
SELECT * FROM v_insurance_firm_mismatches LIMIT 20;
SELECT * FROM v_insurance_firm_incomplete LIMIT 20;
```

---

## 📝 Rollback Plan

If something goes wrong:

```sql
-- Option 1: Restore from backup
DROP TABLE insurance_firm;
CREATE TABLE insurance_firm AS SELECT * FROM insurance_firm_backup_YYYYMMDD;

-- Option 2: Drop new columns (keep old data)
ALTER TABLE insurance_firm
DROP COLUMN payer_id_new,
DROP COLUMN name_new,
DROP COLUMN sync_status,
DROP COLUMN sync_details,
DROP COLUMN last_synced_at;
```

---

## 🚦 Recommended Execution Order

1. ✅ **Backup** both tables
2. ✅ **Add new columns** to `insurance_firm`
3. ✅ **Run pre-flight check** - review outputs
4. ✅ **Choose deletion strategy** based on patient impact
5. ✅ **Run main sync** (monitor for errors)
6. ✅ **Run post-sync cleanup**
7. ✅ **Verify all checks** pass
8. ✅ **Decide on migration** to new values
9. ✅ **Update application code** if needed
10. ✅ **Document** any manual cleanup needed

---

## 🎉 Success Criteria

After completion:
- ✅ **0%** orphaned patient_insurance records
- ✅ **>95%** records have all 3 payer IDs populated
- ✅ **100%** records have `sync_status` and `last_synced_at`
- ✅ **<5%** records in `PAYER_ID_ONLY` or `NAME_ONLY` status
- ✅ **0%** garbage records remaining
- ✅ Row count within 5% of `insurance_firm_oa`

---

## 🆘 Troubleshooting

### Issue: High orphaned patient_insurance count
**Solution:** Reassign using post-sync cleanup script before deletion

### Issue: Many records in PAYER_ID_ONLY status
**Solution:** Review names manually - which is correct? Usually OA is correct

### Issue: Many NO_MATCH records
**Solution:** Verify OA has complete data before running sync

### Issue: Row counts don't match after sync
**Solution:** Expected behavior - garbage was deleted and new records added

### Issue: Application errors after sync
**Solution:** Application still using old columns - they're preserved!

---

## 📞 Next Steps

1. Review all 3 SQL files
2. Backup your data
3. Run pre-flight check
4. Decide on deletion strategy
5. Execute main sync
6. Run post-sync cleanup
7. Verify and monitor
8. Decide on migration strategy
9. Update application code
10. Set up ongoing sync process
