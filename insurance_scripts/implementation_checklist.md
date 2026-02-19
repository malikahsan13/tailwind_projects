# Insurance Firm Data Mapping - Implementation Plan

## 📊 Phased Approach

### Phase 1: Preparation ✅ (Before Running Anything)
1. **Backup Production Data**
   ```sql
   CREATE TABLE insurance_firm_backup_YYYYMMDD AS
   SELECT * FROM insurance_firm;

   CREATE TABLE patient_insurance_backup_YYYYMMDD AS
   SELECT * FROM patient_insurance;
   ```

2. **Run Test Queries** (from `match_logic_reference.sql`)
   - Check for duplicates in `payers_oa`
   - Preview expected matches
   - Identify fuzzy matches

3. **Review Current Data Quality**
   ```sql
   -- Check for NULL payer_ids
   SELECT COUNT(*) FROM insurance_firm WHERE payer_id IS NULL;

   -- Check for duplicate names
   SELECT name, COUNT(*) FROM insurance_firm
   GROUP BY name HAVING COUNT(*) > 1;

   -- Check affected patient records
   SELECT COUNT(*) FROM patient_insurance pi
   JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
   WHERE ifirm.payer_id IS NULL OR ifirm.name IS NULL;
   ```

### Phase 2: Test Environment 🧪
1. **Copy to test/dev database**
2. **Run the solution script** (`insurance_firm_mapping_solution.sql`)
3. **Verify results:**
   ```sql
   -- Check match distribution
   SELECT match_status, COUNT(*) FROM insurance_firm GROUP BY match_status;

   -- Sample exact matches
   SELECT * FROM insurance_firm WHERE match_status = 'EXACT_MATCH' LIMIT 10;

   -- Review problematic matches
   SELECT * FROM v_insurance_firm_review;
   ```
4. **Validate patient_insurance still links correctly**
   ```sql
   SELECT COUNT(*) AS orphaned_records
   FROM patient_insurance pi
   LEFT JOIN insurance_firm ifirm ON pi.insurance_firm_id = ifirm.firm_id
   WHERE ifirm.firm_id IS NULL;
   ```

### Phase 3: Production Execution 🚀
1. **Create final backup**
2. **Run during low-traffic period**
3. **Monitor for errors**
4. **Run verification queries**

### Phase 4: Post-Migration Cleanup 🧹
1. **Review and resolve PAYER_ID_ONLY matches**
   - Compare names manually
   - Update to correct values
   - Change match_status to EXACT_MATCH after verification

2. **Review and resolve NAME_ONLY matches**
   - Verify correct payer_id
   - Update payer_id
   - Change match_status to EXACT_MATCH after verification

3. **Handle NO_MATCH records**
   - Option A: Add missing payers to `payers_oa`
   - Option B: Mark as inactive/invalid
   - Option C: Leave for manual review

4. **Update application code** (if needed)
   - Use new columns: `facility_payer_id`, `professional_payer_id`, `eligibility_payer_id`
   - Handle different match statuses appropriately

## ⚠️ Critical Considerations

### 1. Referential Integrity
Since `patient_insurance` references `insurance_firm`:
- ✅ The solution doesn't change `firm_id`, so referential integrity is maintained
- ⚠️ Verify no orphaned records after update

### 2. Application Impact
- If app queries use `insurance_firm.payer_id`, ensure compatibility
- Consider if you need to update the single `payer_id` column to the correct value

### 3. Data discrepancies
- **PAYER_ID_ONLY**: Names don't match → Which is correct? Check payers_oa source
- **NAME_ONLY**: Different payer_ids for same name → Could be different payer plans
- **NO_MATCH**: May need new payer creation or data cleanup

### 4. Sync Strategy
Going forward, you'll need to:
1. Periodically re-run the match logic
2. Set up triggers or scheduled jobs
3. Consider making `payers_oa` the master/source of truth

## 📈 Success Metrics

| Metric | Target | Query |
|--------|--------|-------|
| Exact Match Rate | > 80% | `SELECT COUNT(*) FROM insurance_firm WHERE match_status = 'EXACT_MATCH'` |
| Orphaned Records | 0 | Check patient_insurance joins |
| Data Completeness | 100% | All new columns populated |

## 🔧 Troubleshooting

### Issue: Low exact match rate
**Solution:**
- Check for case sensitivity issues
- Look for trailing/leading spaces: `SELECT payer_id, '|' || name || '|' FROM insurance_firm`
- Consider fuzzy matching for names

### Issue: Too many NO_MATCH records
**Solution:**
- Verify `payers_oa` has complete data
- Check if payer_id format differs (leading zeros, etc.)
- Manual data entry may be required

### Issue: Patient insurance breaks
**Solution:**
- Restore from backup
- Verify `firm_id` wasn't modified (it shouldn't be)
- Check application queries

## 📞 Next Steps

1. Review the generated SQL files
2. Run test queries on your data
3. Decide on auto-correction strategy (Step 5 in main script)
4. Execute in test environment first
5. Plan production cutover window
6. Document any manual cleanup needed
