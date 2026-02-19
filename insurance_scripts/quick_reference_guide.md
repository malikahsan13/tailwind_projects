# Quick Reference Guide - Insurance Firm Sync

## 📋 Execution Order

### Step 1: Run the Main Sync Script
```bash
# File: sync_from_insurance_firm_oa.sql
```
This will:
- Match `insurance_firm` with `insurance_firm_oa`
- Update all payer_id fields (fac, pro, elig)
- Update all flag fields (non_par, secondary_ins, attachment, wc_auto)
- Set match_status flags

### Step 2: Review the Summary
After running the script, you'll see:
- **EXACT_MATCH** % → Should be highest (hopefully >80%)
- **PAYER_ID_ONLY** % → Names differ, payer_id same
- **NAME_ONLY** % → Payer_ids differ, name same
- **NO_MATCH** % → No correlation found

### Step 3: Handle Problematic Records
```bash
# File: handle_problematic_matches.sql
```

Choose your strategy for each match type:

| Match Type | Recommendation | Action |
|------------|----------------|--------|
| EXACT_MATCH | ✅ Perfect | Already synced automatically |
| PAYER_ID_ONLY | Use OA name | Run Option A in handle script |
| NAME_ONLY | Use OA payer_id | Run Option A in handle script |
| NO_MATCH | Depends | See below |

### Step 4: Handle NO_MATCH (3 Options)

**Option A: Match via sub-payer IDs**
- If `payer_id_fac`, `payer_id_pro`, or `payer_id_elig` exist in OA
- Auto-match using those

**Option B: Add missing payers to OA**
- Insert missing records into `insurance_firm_oa`
- Then re-run sync script

**Option C: Mark as invalid**
- For test/demo/deleted records
- Mark for cleanup

### Step 5: Final Verification
```sql
-- Check match distribution
SELECT match_status, COUNT(*) FROM insurance_firm GROUP BY match_status;

-- Verify data integrity
SELECT COUNT(*) FROM patient_insurance pi
JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id;

-- Check NULL values
SELECT
    SUM(CASE WHEN payer_id_fac IS NULL THEN 1 ELSE 0 END) AS null_fac,
    SUM(CASE WHEN payer_id_pro IS NULL THEN 1 ELSE 0 END) AS null_pro,
    SUM(CASE WHEN payer_id_elig IS NULL THEN 1 ELSE 0 END) AS null_elig
FROM insurance_firm;
```

---

## 🔍 Column Mapping Reference

### insurance_firm_oa (Source) → insurance_firm (Target)

| Source Column | Target Column | Description |
|--------------|---------------|-------------|
| payer_id | payer_id | Main payer identifier |
| name | name | Payer name |
| payer_id_fac | payer_id_fac | Facility payer ID |
| payer_id_fac_enrollment | payer_id_fac_enrollment | Facility enrollment status |
| payer_id_pro | payer_id_pro | Professional payer ID |
| payer_id_pro_enrollment | payer_id_pro_enrollment | Professional enrollment |
| payer_id_elig | payer_id_elig | Eligibility payer ID |
| payer_id_elig_enrollment | payer_id_elig_enrollment | Eligibility enrollment |
| non_par_fac | non_par_fac | Non-participating facility flag |
| non_par_pro | non_par_pro | Non-participating professional flag |
| non_par_elig | non_par_elig | Non-participating eligibility flag |
| secondary_ins_fac | secondary_ins_fac | Secondary insurance facility |
| secondary_ins_pro | secondary_ins_pro | Secondary insurance professional |
| secondary_ins_elig | secondary_ins_elig | Secondary insurance eligibility |
| attachment_fac | attachment_fac | Attachment required facility |
| attachment_pro | attachment_pro | Attachment required professional |
| attachment_elig | attachment_elig | Attachment required eligibility |
| wc_auto_fac | wc_auto_fac | Workers comp auto facility |
| wc_auto_pro | wc_auto_pro | Workers comp auto professional |
| wc_auto_elig | wc_auto_elig | Workers comp auto eligibility |

---

## ⚠️ Important Notes

### 1. Match Status Values

```
EXACT_MATCH              → Both payer_id and name match perfectly
PAYER_ID_ONLY            → payer_id matches but name differs
NAME_ONLY                → name matches but payer_id differs
NO_MATCH                 → No correlation found
CORRECTED_PAYER_ID_ONLY  → Was PAYER_ID_ONLY, now fixed
CORRECTED_NAME_ONLY      → Was NAME_ONLY, now fixed
MATCHED_VIA_SUB_PAYER    → Was NO_MATCH, matched via sub-payer ID
INVALID_PAYER            → Marked for deletion
```

### 2. Flag Values (Yes/No)

All flag columns should contain:
- `'Yes'` or `'No'` (case-sensitive based on your data)
- Check what format is in `insurance_firm_oa`

### 3. Referential Integrity

✅ **Safe**: This script does NOT modify `firm_id`
✅ **Safe**: All `patient_insurance` references remain valid
⚠️ **Check**: Run verification queries after update

### 4. Performance

For large tables (>100K records):
- Run during low-traffic hours
- Consider running in batches
- Add indexes if needed:
  ```sql
  CREATE INDEX idx_firm_payer_id ON insurance_firm(payer_id);
  CREATE INDEX idx_firm_name ON insurance_firm(name);
  CREATE INDEX idx_oa_payer_id ON insurance_firm_oa(payer_id);
  CREATE INDEX idx_oa_name ON insurance_firm_oa(name);
  ```

---

## 🚨 Troubleshooting

### Issue: Too many NO_MATCH records
**Cause**: Payer_id or name format differs significantly
**Solution**:
1. Check for case sensitivity
2. Check for extra spaces: `SELECT '|' || name || '|' FROM insurance_firm`
3. Try fuzzy matching

### Issue: Update takes too long
**Cause**: Large table without indexes
**Solution**: Create indexes on `payer_id` and `name` columns

### Issue: PAYER_ID_ONLY has too many records
**Cause**: Names are abbreviated differently
**Solution**: Review and decide on source of truth (usually OA)

---

## 📊 Success Metrics

After completion, you should have:

- ✅ **>90%** records with `payer_id_fac`, `payer_id_pro`, `payer_id_elig` populated
- ✅ **0** orphaned `patient_insurance` records
- ✅ **<5%** records in `NO_MATCH` or problematic status
- ✅ **100%** records have `match_status` and `last_synced_at` set

---

## 🔄 Ongoing Sync Strategy

### Option 1: Scheduled Updates
```sql
-- Run daily/weekly to catch new records
-- Re-run sync_from_insurance_firm_oa.sql
```

### Option 2: Triggers
```sql
-- Auto-sync when insurance_firm_oa is updated
CREATE TRIGGER sync_insurance_firm
AFTER INSERT OR UPDATE ON insurance_firm_oa
FOR EACH ROW
BEGIN
    -- Update corresponding insurance_firm record
END;
```

### Option 3: Application-Level Sync
- Update application to read from `insurance_firm_oa`
- Use `insurance_firm` as cached/denormalized data
- Sync periodically via background job

---

## 📝 Pre-Execution Checklist

- [ ] Backup `insurance_firm` table
- [ ] Backup `patient_insurance` table
- [ ] Run test queries on sample data
- [ ] Verify `insurance_firm_oa` has correct data
- [ ] Schedule maintenance window
- [ ] Inform stakeholders of potential data changes
- [ ] Prepare rollback plan
- [ ] Document any custom business logic

---

## 📞 Next Steps

1. ✅ Review all three SQL files
2. ✅ Run `sync_from_insurance_firm_oa.sql`
3. ✅ Check match summary
4. ✅ Run `handle_problematic_matches.sql` (selective options)
5. ✅ Verify data integrity
6. ✅ Update application code if needed
7. ✅ Set up ongoing sync strategy
