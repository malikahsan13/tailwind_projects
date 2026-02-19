# 🚀 Quick Start Guide - Insurance Firm Sync V2

## ⚡ Fastest Path to Completion

### Option 1: Automated Script (Recommended)

**Windows:**
```cmd
run_sync.bat your_database_name root [password]
```

**Linux/Mac:**
```bash
chmod +x run_sync.sh
./run_sync.sh your_database_name root [password]
```

### Option 2: Manual Step-by-Step

```bash
# Step 1: Setup
mysql -u root -p your_db < step1_setup/01_add_columns.sql
mysql -u root -p your_db < step1_setup/02_verify_columns.sql

# Step 2: Check (review output carefully!)
mysql -u root -p your_db < step2_check/01_data_quality.sql
mysql -u root -p your_db < step2_check/02_predict_matches.sql
mysql -u root -p your_db < step2_check/03_patient_impact.sql

# Step 3: Sync
mysql -u root -p your_db < step3_sync/01_update_matching.sql
mysql -u root -p your_db < step3_sync/02_delete_garbage.sql
mysql -u root -p your_db < step3_sync/03_insert_new.sql

# Step 4: Verify
mysql -u root -p your_db < step4_verify/01_sync_summary.sql
mysql -u root -p your_db < step4_verify/02_data_completeness.sql
mysql -u root -p your_db < step4_verify/03_patient_integrity.sql
mysql -u root -p your_db < step4_verify/04_cleanup.sql
```

---

## 📋 Pre-Flight Checklist (Before Starting)

- [ ] **Backup created:**
  ```sql
  CREATE TABLE insurance_firm_backup_YYYYMMDD AS SELECT * FROM insurance_firm;
  CREATE TABLE patient_insurance_backup_YYYYMMDD AS SELECT * FROM patient_insurance;
  ```

- [ ] **Verified tables exist:**
  ```sql
  SHOW TABLES LIKE '%insurance_firm%';
  ```

- [ ] **Noted current row counts:**
  ```sql
  SELECT COUNT(*) FROM insurance_firm;
  SELECT COUNT(*) FROM insurance_firm_oa;
  SELECT COUNT(*) FROM patient_insurance;
  ```

- [ ] **Scheduled maintenance window** (if production)

---

## 📊 After Sync - Quick Verification

```sql
-- 1. Check sync status
SELECT sync_status, COUNT(*) FROM insurance_firm GROUP BY sync_status;

-- 2. Check data completeness
SELECT
    SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) AS fac,
    SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) AS pro,
    SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) AS elig
FROM insurance_firm;

-- 3. Check for orphans
SELECT COUNT(*) FROM patient_insurance pi
LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
WHERE ifirm.firm_id IS NULL;  -- Should be 0

-- 4. View dashboard
SELECT * FROM v_insurance_firm_sync_dashboard;

-- 5. Review needs action
SELECT * FROM v_insurance_firm_needs_review LIMIT 20;
```

---

## ⚠️ Critical Decision Point

**After running `step2_check/03_patient_impact.sql`:**

### If patient_impact = 0
→ Use **Option A** (Safe deletion) - **Already configured**

### If patient_impact > 0
→ Edit `step3_sync/02_delete_garbage.sql`:
  - **Option A:** Delete only safe records
  - **Option B:** Reassign then delete (uncomment)
  - **Option C:** Delete all, handle orphans later (uncomment)

---

## 🎯 Expected Results

| Metric | Target | Query |
|--------|--------|-------|
| Sync completion | 100% | `SELECT COUNT(*) WHERE sync_status IS NOT NULL` |
| Data completeness | >95% | Check fac/pro/elig populated |
| Orphaned patients | 0 | Patient insurance join |
| Exact matches | >70% | `sync_status = 'EXACT_MATCH'` |
| Row count | ≈ OA count | `SELECT COUNT(*) FROM insurance_firm` |

---

## 🔧 Troubleshooting Quick Fixes

### Error: "Unknown column"
**Fix:** Run step1_setup first
```bash
mysql -u root -p your_db < step1_setup/01_add_columns.sql
```

### Too many NO_MATCH records
**Fix:** Review prediction output in step2_check
```bash
mysql -u root -p your_db < step2_check/02_predict_matches.sql
```

### Orphaned patient records
**Fix:** See troubleshooting guide
```bash
mysql -u root -p your_db < step4_verify/03_patient_integrity.sql
```

---

## 📁 File Organization

```
insurance_firm_sync_v2/
├── README.md                     ← Start here
├── run_sync.bat                  ← Windows automation
├── run_sync.sh                   ← Linux/Mac automation
├── docs/                         ← Documentation
├── step1_setup/                  ← Add columns
├── step2_check/                  ← Analyze data
├── step3_sync/                   ← Run sync
└── step4_verify/                 ← Verify results
```

---

## ✅ Success Checklist

After completion:
- [ ] All 12 scripts executed without errors
- [ ] Sync status shows high match rate
- [ ] Data completeness >95%
- [ ] Zero orphaned patient records
- [ ] Views created successfully
- [ ] Dashboard query runs successfully
- [ ] Reviewed records in needs_review view
- [ ] Documented any issues
- [ ] Team notified of changes

---

## 📞 Need Help?

- **Complete Guide:** `docs/00_START_HERE.md`
- **Column Reference:** `docs/01_column_reference.md`
- **Troubleshooting:** `docs/02_troubleshooting.md`
- **Full README:** `README.md`

---

## 🔄 Rollback (If Needed)

```sql
-- Restore from backup
DROP TABLE insurance_firm;
CREATE TABLE insurance_firm AS SELECT * FROM insurance_firm_backup_YYYYMMDD;
```

---

**Ready? Start with `run_sync.bat` or `run_sync.sh`!** 🚀
