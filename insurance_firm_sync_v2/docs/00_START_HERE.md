# Insurance Firm Sync - Complete Guide
## MySQL Version - V2 (OA with NULL payer_id)

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Folder Structure](#folder-structure)
4. [Step-by-Step Execution](#step-by-step-execution)
5. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

**Problem:**
- `insurance_firm` table has invalid/corrupt payer data
- `insurance_firm_oa` table has correct data (flattened structure)
- OA.payer_id is NULL, but payer_id_fac, payer_id_pro, payer_id_elig are populated

**Solution:**
1. Add new tracking columns to insurance_firm
2. Match records on fac/pro/elig/name
3. Update matching records with OA data
4. Delete garbage records (not in OA)
5. Insert missing records from OA

**Key Features:**
- ✅ Preserves original `payer_id` and `name` columns
- ✅ Adds `payer_id_new`, `name_new` with correct OA values
- ✅ Tracks changes with `sync_status`, `matched_via`
- ✅ Safe for patient_insurance relationships
- ✅ Complete audit trail

---

## ✅ Prerequisites

### Database Requirements
- MySQL 5.7+ or MariaDB 10.2+
- Existing tables: `insurance_firm`, `insurance_firm_oa`, `patient_insurance`

### Before You Start
1. **BACKUP YOUR DATA!**
   ```sql
   CREATE TABLE insurance_firm_backup_YYYYMMDD AS SELECT * FROM insurance_firm;
   CREATE TABLE patient_insurance_backup_YYYYMMDD AS SELECT * FROM patient_insurance;
   ```

2. **Verify table structures**
   ```sql
   DESCRIBE insurance_firm;
   DESCRIBE insurance_firm_oa;
   ```

3. **Check row counts**
   ```sql
   SELECT COUNT(*) FROM insurance_firm;
   SELECT COUNT(*) FROM insurance_firm_oa;
   SELECT COUNT(*) FROM patient_insurance;
   ```

---

## 📁 Folder Structure

```
insurance_firm_sync_v2/
│
├── docs/
│   ├── 00_START_HERE.md          ← You are here
│   ├── 01_column_reference.md    → Column definitions
│   └── 02_troubleshooting.md     → Common issues & solutions
│
├── step1_setup/
│   ├── 01_add_columns.sql        → Add all new columns
│   └── 02_verify_columns.sql     → Verify columns added
│
├── step2_check/
│   ├── 01_data_quality.sql       → Check data quality
│   ├── 02_predict_matches.sql    → Preview match outcomes
│   └── 03_patient_impact.sql     → Check patient_insurance impact
│
├── step3_sync/
│   ├── 01_update_matching.sql    → Phase 1: Update matching records
│   ├── 02_delete_garbage.sql     → Phase 2: Delete garbage
│   └── 03_insert_new.sql         → Phase 3: Insert new from OA
│
└── step4_verify/
    ├── 01_sync_summary.sql       → Overall summary
    ├── 02_data_completeness.sql  → Check completeness
    ├── 03_patient_integrity.sql  → Verify patient_insurance
    └── 04_cleanup.sql            → Final cleanup & views
```

---

## 🚀 Step-by-Step Execution

### STEP 0: Pre-Execution Checklist

- [ ] Backup created (`insurance_firm_backup_YYYYMMDD`)
- [ ] Backup created (`patient_insurance_backup_YYYYMMDD`)
- [ ] Verified table structures exist
- [ ] Noted current row counts
- [ ] Scheduled maintenance window (if production)
- [ ] Read through all steps

---

### STEP 1: Setup (5 minutes)

**Purpose:** Add all required new columns to `insurance_firm` table

**Files to run:**
```bash
# 1. Add all new columns
mysql -u username -p database_name < step1_setup/01_add_columns.sql

# 2. Verify columns added successfully
mysql -u username -p database_name < step1_setup/02_verify_columns.sql
```

**Expected output:**
- 6 new columns added
- Verification query shows all columns present
- No errors

**⚠️ Stop if:** Any errors occur. Check column names and table structure.

---

### STEP 2: Pre-Sync Analysis (10 minutes)

**Purpose:** Understand your data before running sync

**Files to run:**
```bash
# 1. Check data quality
mysql -u username -p database_name < step2_check/01_data_quality.sql

# 2. Predict match outcomes
mysql -u username -p database_name < step2_check/02_predict_matches.sql

# 3. Check patient_insurance impact
mysql -u username -p database_name < step2_check/03_patient_impact.sql
```

**Key outputs to review:**

1. **Match prediction:**
   - EXACT_MATCH % (should be highest, ideally >70%)
   - PAYER_ID_ONLY % (name differs)
   - NAME_ONLY % (payer_id differs)
   - NO_MATCH % (will be deleted)

2. **Garbage records:**
   - Count of records that will be deleted
   - Are these truly garbage?

3. **Patient impact:**
   - How many patient_insurance records will be orphaned?
   - If > 0, decide on deletion strategy (see STEP 3.2)

**⚠️ Stop if:**
- Too many records in NO_MATCH (>30%)
- Many patient_insurance records will be orphaned
- Data quality issues detected

**Decision point:**
- If patient_impact > 0: Choose deletion strategy in STEP 3.2
  - **Option A:** Safe (delete only garbage with no patient refs)
  - **Option B:** Reassign (reassign patients, then delete)
  - **Option C:** Delete all (will orphans, handle later)

---

### STEP 3: Sync Execution (15-30 minutes)

**Purpose:** Execute the actual data sync in 3 phases

#### STEP 3.1: Update Matching Records
```bash
mysql -u username -p database_name < step3_sync/01_update_matching.sql
```

**What happens:**
- Matches `insurance_firm.payer_id` with OA's fac/pro/elig
- Updates all matching records with OA data
- Sets `payer_id_new`, `name_new`, `matched_via`
- Sets `sync_status` (EXACT_MATCH, PAYER_ID_ONLY, NAME_ONLY)

**Expected output:**
- Records updated count
- Match status distribution
- No errors

**Verify after update:**
```sql
SELECT sync_status, COUNT(*)
FROM insurance_firm
GROUP BY sync_status;
```

---

#### STEP 3.2: Delete Garbage Records
```bash
# Choose ONE option based on STEP 2 analysis:

# Option A: Safe deletion (RECOMMENDED FIRST)
mysql -u username -p database_name < step3_sync/02_delete_garbage.sql
# This deletes only records with NO patient references

# Option B: Reassign then delete
# Edit the file first to uncomment Option B sections
# Then run:
mysql -u username -p database_name < step3_sync/02_delete_garbage.sql

# Option C: Delete all (DANGEROUS)
# Edit the file first to uncomment Option C
# Then run:
mysql -u username -p database_name < step3_sync/02_delete_garbage.sql
```

**What happens:**
- Deletes records not in OA (garbage)
- Based on your chosen option (A/B/C)

**Expected output:**
- Count of deleted records
- Should match prediction from STEP 2

**⚠️ Stop if:** More records deleted than expected

---

#### STEP 3.3: Insert New Records
```bash
mysql -u username -p database_name < step3_sync/03_insert_new.sql
```

**What happens:**
- Inserts records from OA not in insurance_firm
- Populates all columns from OA
- Sets `sync_status = 'NEW_FROM_OA'`

**Expected output:**
- Count of inserted records
- Should match prediction from STEP 2

---

### STEP 4: Verification (10 minutes)

**Purpose:** Verify sync completed successfully

**Files to run:**
```bash
# 1. Overall sync summary
mysql -u username -p database_name < step4_verify/01_sync_summary.sql

# 2. Data completeness check
mysql -u username -p database_name < step4_verify/02_data_completeness.sql

# 3. Patient insurance integrity
mysql -u username -p database_name < step4_verify/03_patient_integrity.sql

# 4. Final cleanup and views
mysql -u username -p database_name < step4_verify/04_cleanup.sql
```

**Expected results:**

✅ **Success criteria:**
- [ ] 100% records have `sync_status` set
- [ ] >95% records have all 3 payer IDs (fac/pro/elig) populated
- [ ] 0 orphaned patient_insurance records
- [ ] Row count matches OA (within 5%)
- [ ] <5% records in PAYER_ID_ONLY or NAME_ONLY status
- [ ] `matched_via` distribution makes sense

❌ **If any criteria fail:**
- Review troubleshooting guide
- Run appropriate fix queries
- May need to re-run specific phases

---

## 📊 Post-Sync Actions

### 1. Review Problematic Records
```sql
-- View records with issues
SELECT * FROM v_insurance_firm_mismatches;
SELECT * FROM v_insurance_firm_incomplete;
```

### 2. Decide on Migration
After verification, decide if you want to migrate to new values:

**Option A: Keep both old and new**
- Application uses `payer_id_new` and `name_new`
- Old columns preserved for audit
- Gradual migration

**Option B: Migrate to new values**
```sql
-- Run this AFTER confirming new values are correct
UPDATE insurance_firm
SET payer_id = payer_id_new,
    name = name_new
WHERE payer_id != payer_id_new OR name != name_new;
```

### 3. Update Application Code
- Change queries to use new columns if needed
- Update forms to use new payer IDs
- Test thoroughly in dev environment first

---

## 🔧 Troubleshooting

See [docs/02_troubleshooting.md](02_troubleshooting.md) for:
- Common errors and solutions
- Rollback procedures
- Data quality fixes
- Performance optimization

---

## 📞 Quick Reference

### File Execution Order
```
step1_setup/01_add_columns.sql
step1_setup/02_verify_columns.sql
step2_check/01_data_quality.sql
step2_check/02_predict_matches.sql
step2_check/03_patient_impact.sql
step3_sync/01_update_matching.sql
step3_sync/02_delete_garbage.sql
step3_sync/03_insert_new.sql
step4_verify/01_sync_summary.sql
step4_verify/02_data_completeness.sql
step4_verify/03_patient_integrity.sql
step4_verify/04_cleanup.sql
```

### Key Columns Reference
- `payer_id` - Original (preserved)
- `payer_id_new` - Correct value from OA
- `name` - Original (preserved)
- `name_new` - Correct value from OA
- `matched_via` - Match source: 'fac', 'pro', 'elig', 'name'
- `sync_status` - Match quality: EXACT_MATCH, PAYER_ID_ONLY, etc.

### Rollback (if needed)
```sql
-- Restore from backup
DROP TABLE insurance_firm;
CREATE TABLE insurance_firm AS SELECT * FROM insurance_firm_backup_YYYYMMDD;
```

---

## ✅ Success Checklist

After completing all steps:
- [ ] All scripts executed without errors
- [ ] Pre-flight predictions matched actual results
- [ ] Sync status shows high match rate
- [ ] Data completeness >95%
- [ ] Zero orphaned patient records
- [ ] Views created successfully
- [ ] Documentation updated
- [ ] Team notified of changes
- [ ] Application tested with new data
- [ ] Monitoring setup for ongoing syncs

---

## 📝 Notes

**Execution time:** 30-60 minutes (depending on data size)

**Maintenance:**
- Run periodically to sync new changes from OA
- Consider setting up automated sync job
- Monitor `sync_status` distribution

**Support:**
- Document any custom modifications
- Keep rollback backups for at least 1 week
- Test all queries in non-production first

---

**Ready to start? Go to STEP 1!** 🚀
