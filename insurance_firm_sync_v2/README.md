# Insurance Firm Sync - Complete Step-by-Step Scripts

**MySQL Version | V2 | For OA with NULL payer_id**

---

## 🎯 Quick Start

```bash
# Navigate to the folder
cd insurance_firm_sync_v2

# Run all steps in order
mysql -u username -p database_name < step1_setup/01_add_columns.sql
mysql -u username -p database_name < step1_setup/02_verify_columns.sql
mysql -u username -p database_name < step2_check/01_data_quality.sql
mysql -u username -p database_name < step2_check/02_predict_matches.sql
mysql -u username -p database_name < step2_check/03_patient_impact.sql
mysql -u username -p database_name < step3_sync/01_update_matching.sql
mysql -u username -p database_name < step3_sync/02_delete_garbage.sql
mysql -u username -p database_name < step3_sync/03_insert_new.sql
mysql -u username -p database_name < step4_verify/01_sync_summary.sql
mysql -u username -p database_name < step4_verify/02_data_completeness.sql
mysql -u username -p database_name < step4_verify/03_patient_integrity.sql
mysql -u username -p database_name < step4_verify/04_cleanup.sql
```

---

## 📁 Folder Structure

```
insurance_firm_sync_v2/
│
├── README.md                      ← You are here
├── docs/
│   ├── 00_START_HERE.md          → Complete guide
│   ├── 01_column_reference.md    → Column definitions
│   └── 02_troubleshooting.md     → Troubleshooting guide
│
├── step1_setup/                   ← Add new columns
│   ├── 01_add_columns.sql
│   └── 02_verify_columns.sql
│
├── step2_check/                   ← Pre-sync analysis
│   ├── 01_data_quality.sql
│   ├── 02_predict_matches.sql
│   └── 03_patient_impact.sql
│
├── step3_sync/                    ← Execute sync
│   ├── 01_update_matching.sql     → Phase 1: Update
│   ├── 02_delete_garbage.sql      → Phase 2: Delete
│   └── 03_insert_new.sql          → Phase 3: Insert
│
└── step4_verify/                  ← Verify & cleanup
    ├── 01_sync_summary.sql
    ├── 02_data_completeness.sql
    ├── 03_patient_integrity.sql
    └── 04_cleanup.sql
```

---

## ⚡ Quick Reference

### Execution Order (12 scripts total)

| Step | Script | Purpose | Time |
|------|--------|---------|------|
| 1.1 | `step1_setup/01_add_columns.sql` | Add 6 new columns | 1 min |
| 1.2 | `step1_setup/02_verify_columns.sql` | Verify columns added | 1 min |
| 2.1 | `step2_check/01_data_quality.sql` | Check data quality | 2 min |
| 2.2 | `step2_check/02_predict_matches.sql` | Predict outcomes | 3 min |
| 2.3 | `step2_check/03_patient_impact.sql` | Check patient impact | 2 min |
| 3.1 | `step3_sync/01_update_matching.sql` | Update matching records | 5-15 min |
| 3.2 | `step3_sync/02_delete_garbage.sql` | Delete garbage | 2-5 min |
| 3.3 | `step3_sync/03_insert_new.sql` | Insert new records | 2-5 min |
| 4.1 | `step4_verify/01_sync_summary.sql` | Overall summary | 1 min |
| 4.2 | `step4_verify/02_data_completeness.sql` | Check completeness | 1 min |
| 4.3 | `step4_verify/03_patient_integrity.sql` | Verify patients | 1 min |
| 4.4 | `step4_verify/04_cleanup.sql` | Create views | 1 min |

**Total time:** 30-60 minutes

---

## 📊 New Columns Added

| Column | Type | Purpose |
|--------|------|---------|
| `payer_id_new` | VARCHAR(200) | Correct payer ID from OA |
| `name_new` | VARCHAR(255) | Correct name from OA |
| `sync_status` | VARCHAR(50) | Match quality indicator |
| `sync_details` | TEXT | Detailed sync information |
| `last_synced_at` | TIMESTAMP | Audit timestamp |
| `matched_via` | VARCHAR(10) | Match source: 'fac', 'pro', 'elig', 'name' |

---

## 🎯 Sync Status Values

| Status | Meaning | Action |
|--------|---------|--------|
| `EXACT_MATCH` | Perfect match | ✓ Good |
| `PAYER_ID_ONLY` | Payer ID matches, name differs | ⚠️ Review |
| `NAME_ONLY` | Name matches, payer ID differs | ⚠️ Review |
| `NEW_FROM_OA` | New record inserted | ✓ Good |
| `NO_MATCH` | No correlation | Deleted as garbage |

---

## ✅ Success Criteria

After running all scripts:

- [ ] 100% records have `sync_status` set
- [ ] >95% records have all 3 payer IDs (fac/pro/elig) populated
- [ ] 0 orphaned `patient_insurance` records
- [ ] Row count matches `insurance_firm_oa` (within 5%)
- [ ] <5% records in `PAYER_ID_ONLY` or `NAME_ONLY` status
- [ ] `matched_via` distribution makes sense

---

## 🔍 Key Views Created

After completion, these views are available:

```sql
-- Overall statistics
SELECT * FROM v_insurance_firm_sync_dashboard;

-- Records needing review
SELECT * FROM v_insurance_firm_needs_review;

-- Incomplete records
SELECT * FROM v_insurance_firm_incomplete;

-- Records with mismatches
SELECT * FROM v_insurance_firm_mismatches;

-- Recent sync activity
SELECT * FROM v_insurance_firm_recent_sync;

-- Detailed payer ID analysis
SELECT * FROM v_insurance_firm_payer_id_analysis;
```

---

## ⚠️ Important Notes

### Before Starting
1. **BACKUP YOUR DATA!**
   ```sql
   CREATE TABLE insurance_firm_backup_YYYYMMDD AS SELECT * FROM insurance_firm;
   CREATE TABLE patient_insurance_backup_YYYYMMDD AS SELECT * FROM patient_insurance;
   ```

2. Run in **test environment first**

3. Schedule **maintenance window** if production

### Key Decision Point
After `step2_check/03_patient_impact.sql`:
- If patient impact = 0: Use **Option A** (default)
- If patient impact > 0: Choose **Option A**, **B**, or **C** in `step3_sync/02_delete_garbage.sql`

### Matching Logic
This script assumes:
- `insurance_firm_oa.payer_id` is **NULL**
- `insurance_firm_oa.payer_id_fac`, `payer_id_pro`, `payer_id_elig` are **populated**
- Match logic: `insurance_firm.payer_id` matches OA's fac/pro/elig

---

## 🆘 Troubleshooting

### Error: "Unknown column 'matched_via'"
**Solution:** Run `step1_setup/01_add_columns.sql` first

### Error: "Table doesn't exist"
**Solution:** Verify table names in your database:
```sql
SHOW TABLES LIKE '%insurance_firm%';
```

### Too many NO_MATCH records
**Solution:**
- Review `step2_check/02_predict_matches.sql` output
- Check OA data quality
- Verify matching logic matches your data

### Orphaned patient records
**Solution:**
- Review `step4_verify/03_patient_integrity.sql`
- Run reassignment query if needed
- See `docs/02_troubleshooting.md`

---

## 📞 Quick Queries

### Check sync progress
```sql
SELECT sync_status, COUNT(*)
FROM insurance_firm
GROUP BY sync_status;
```

### Check matched_via distribution
```sql
SELECT matched_via, COUNT(*)
FROM insurance_firm
WHERE sync_status IS NOT NULL
GROUP BY matched_via;
```

### Find incomplete records
```sql
SELECT * FROM v_insurance_firm_incomplete
LIMIT 20;
```

### Check data quality
```sql
SELECT
    SUM(CASE WHEN payer_id_fac IS NOT NULL THEN 1 ELSE 0 END) AS fac_count,
    SUM(CASE WHEN payer_id_pro IS NOT NULL THEN 1 ELSE 0 END) AS pro_count,
    SUM(CASE WHEN payer_id_elig IS NOT NULL THEN 1 ELSE 0 END) AS elig_count
FROM insurance_firm;
```

---

## 🔄 Rollback

If something goes wrong:
```sql
-- Restore from backup
DROP TABLE insurance_firm;
CREATE TABLE insurance_firm AS SELECT * FROM insurance_firm_backup_YYYYMMDD;
```

---

## 📚 Documentation

- **Complete Guide:** `docs/00_START_HERE.md`
- **Column Reference:** `docs/01_column_reference.md`
- **Troubleshooting:** `docs/02_troubleshooting.md`

---

## ✨ Features

- ✅ Preserves original `payer_id` and `name`
- ✅ Adds new columns with correct values
- ✅ Tracks all changes with audit trail
- ✅ Safe for patient_insurance relationships
- ✅ Creates monitoring views
- ✅ Detailed verification queries
- ✅ Multiple deletion strategies
- ✅ Complete error handling

---

**Ready to start? See `docs/00_START_HERE.md` for complete guide!** 🚀
