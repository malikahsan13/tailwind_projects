# matched_via Column - Complete Explanation

## 📋 What is matched_via?

The `matched_via` column tracks **which column** was used to match `insurance_firm` with `insurance_firm_oa`.

### Possible Values:
| Value | Meaning | Example |
|-------|---------|---------|
| `'fac'` | Matched on `payer_id_fac` | Old `payer_id` = OA's `payer_id_fac` |
| `'pro'` | Matched on `payer_id_pro` | Old `payer_id` = OA's `payer_id_pro` |
| `'elig'` | Matched on `payer_id_elig` | Old `payer_id` = OA's `payer_id_elig` |
| `'name'` | Matched on `name` column | Names match, but no payer ID match |
| `NULL` | No match found | Garbage record |

---

## 🔍 How It Works

### In the CREATE TEMPORARY TABLE:

```sql
CREATE TEMPORARY TABLE IF NOT EXISTS insurance_firm_sync_analysis AS
SELECT
    ifirm.firm_id,
    ifirm.payer_id AS old_payer_id,
    ifirm.name AS old_name,
    ...
    -- Track which column matched
    CASE
        WHEN ifirm.payer_id = if_oa.payer_id_fac THEN 'fac'
        WHEN ifirm.payer_id = if_oa.payer_id_pro THEN 'pro'
        WHEN ifirm.payer_id = if_oa.payer_id_elig THEN 'elig'
        WHEN LOWER(ifirm.name) = LOWER(if_oa.name) THEN 'name'
        ELSE NULL
    END AS matched_via,  -- ← This creates the column in temp table
    ...
FROM insurance_firm ifirm
INNER JOIN insurance_firm_oa if_oa
    ON ifirm.payer_id = if_oa.payer_id_fac
    OR ifirm.payer_id = if_oa.payer_id_pro
    OR ifirm.payer_id = if_oa.payer_id_elig
    OR LOWER(ifirm.name) = LOWER(if_oa.name);
```

### In the UPDATE Statement:

```sql
UPDATE insurance_firm tgt
SET
    ...
    matched_via = ma.matched_via,  -- ← Copies from temp table to insurance_firm
    ...
FROM insurance_firm_sync_analysis ma
WHERE tgt.firm_id = ma.firm_id;
```

---

## 📊 Example Data Flow

### Example 1: Match via fac
```
BEFORE:
insurance_firm:
┌─────────┬──────────┬─────────────┐
│ firm_id │ payer_id │ name        │
├─────────┼──────────┼─────────────┤
│ 1       │ FAC001   │ Aetna Inc   │
└─────────┴──────────┴─────────────┘

insurance_firm_oa:
┌──────────┬─────────────┬─────────────┐
│ name     │ payer_id_fac│ payer_id_pro│
├──────────┼─────────────┼─────────────┤
│ Aetna    │ FAC001      │ PRO001      │
└──────────┴─────────────┴─────────────┘

TEMP TABLE (insurance_firm_sync_analysis):
┌─────────┬───────────────┬──────────────┬─────────────┐
│ firm_id │ old_payer_id  │ matched_via  │ match_status│
├─────────┼───────────────┼─────────────┼─────────────┤
│ 1       │ FAC001        │ 'fac'        │ PAYER_ID_...│
└─────────┴───────────────┴─────────────┴─────────────┘
                          ↑
                    Determined by CASE statement

AFTER UPDATE:
insurance_firm:
┌─────────┬──────────┬─────────────┬─────────────┬──────────────┐
│ firm_id │ payer_id │ name        │ payer_id_new│ matched_via  │
├─────────┼──────────┼─────────────┼─────────────┼──────────────┤
│ 1       │ FAC001   │ Aetna Inc   │ FAC001      │ 'fac'        │
└─────────┴──────────┴─────────────┴─────────────┴──────────────┘
                                                  ↑
                                      Populated from temp table
```

### Example 2: Match via name
```
BEFORE:
insurance_firm:
┌─────────┬──────────┬─────────────┐
│ firm_id │ payer_id │ name        │
├─────────┼──────────┼─────────────┤
│ 2       │ OLD002   │ Blue Cross  │
└─────────┴──────────┴─────────────┘

insurance_firm_oa:
┌──────────┬─────────────┬─────────────┬─────────────┐
│ name     │ payer_id_fac│ payer_id_pro│ payer_id_elig│
├──────────┼─────────────┼─────────────┼─────────────┤
│ Blue Cross│ NULL       │ PRO002      │ ELIG002     │
└──────────┴─────────────┴─────────────┴─────────────┘

TEMP TABLE:
┌─────────┬───────────────┬──────────────┬─────────────┐
│ firm_id │ old_payer_id  │ matched_via  │ match_status│
├─────────┼───────────────┼─────────────┼─────────────┤
│ 2       │ OLD002        │ 'name'       │ NAME_ONLY   │
└─────────┴───────────────┴─────────────┴─────────────┘
                          ↑
                    Matched on name, not payer_id

AFTER UPDATE:
insurance_firm:
┌─────────┬──────────┬─────────────┬─────────────┬──────────────┐
│ firm_id │ payer_id │ name        │ payer_id_new│ matched_via  │
├─────────┼──────────┼─────────────┼─────────────┼──────────────┤
│ 2       │ OLD002   │ Blue Cross  │ PRO002      │ 'name'       │
└─────────┴──────────┴─────────────┴─────────────┴──────────────┘
                                        ↑           ↑
                                   From pro     Matched via name
```

---

## ⚠️ Critical Steps

### Step 1: Add Column to Table (Required!)
```sql
ALTER TABLE `insurance_firm`
ADD COLUMN `matched_via` VARCHAR(10) NULL
AFTER `last_synced_at`;
```

**This MUST be done BEFORE running the sync script!**

### Step 2: Run Sync Script
The sync script will:
1. Create temp table with `matched_via` (calculated via CASE)
2. Update `insurance_firm.matched_via` from temp table

### Step 3: Verify
```sql
SELECT
    firm_id,
    payer_id AS old_payer_id,
    payer_id_new,
    name,
    name_new,
    matched_via,
    sync_status
FROM insurance_firm
WHERE sync_status IS NOT NULL
ORDER BY last_synced_at DESC
LIMIT 20;
```

---

## 🔧 Troubleshooting

### Error: "Unknown column 'matched_via'"

**Cause:** Column doesn't exist in `insurance_firm` table

**Solution:** Run the column setup script first:
```bash
mysql < complete_column_setup.sql
```

### Error: "Unknown column 'matched_via' in field list"

**Cause:** Trying to update `matched_via` but column doesn't exist

**Solution:** Same as above - add the column first

### All matched_via values are NULL

**Cause:** No matches found, or logic issue

**Solution:** Check match_status distribution:
```sql
SELECT sync_status, matched_via, COUNT(*)
FROM insurance_firm
GROUP BY sync_status, matched_via;
```

---

## 📊 Query Examples

### See distribution of matched_via values:
```sql
SELECT
    matched_via,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM insurance_firm), 2) AS percentage
FROM insurance_firm
WHERE sync_status IS NOT NULL
GROUP BY matched_via
ORDER BY count DESC;
```

Expected output:
```
┌─────────────┬────────┬────────────┐
│ matched_via │ count  │ percentage │
├─────────────┼────────┼────────────┤
│ fac         │ 450    │ 45.00%     │
│ pro         │ 300    │ 30.00%     │
│ elig        │ 150    │ 15.00%     │
│ name        │ 100    │ 10.00%     │
└─────────────┴────────┴────────────┘
```

### Filter by matched_via:
```sql
-- See all records matched via fac
SELECT * FROM insurance_firm
WHERE matched_via = 'fac';

-- See all records matched via name (NAME_ONLY status)
SELECT * FROM insurance_firm
WHERE matched_via = 'name'
  AND sync_status = 'NAME_ONLY';
```

### Combined analysis:
```sql
SELECT
    matched_via,
    sync_status,
    COUNT(*) AS count
FROM insurance_firm
WHERE matched_via IS NOT NULL
GROUP BY matched_via, sync_status
ORDER BY matched_via, sync_status;
```

---

## ✅ Verification Checklist

Before running the sync script, verify:

- [ ] `matched_via` column exists in `insurance_firm` table
- [ ] `matched_via` column is VARCHAR(10) or similar
- [ ] `matched_via` column allows NULL values
- [ ] All other new columns exist (`payer_id_new`, `name_new`, etc.)

After running the sync script, verify:

- [ ] `matched_via` is populated (not all NULL)
- [ ] Values are one of: 'fac', 'pro', 'elig', 'name', NULL
- [ ] Distribution makes sense (see query above)
- [ ] Combined with `sync_status`, tells clear story

---

## 📞 Quick Summary

1. **Add column first**: Run `complete_column_setup.sql`
2. **Run sync**: Temp table calculates `matched_via` → Updates `insurance_firm.matched_via`
3. **Verify**: Check distribution and sample data
4. **Use for analysis**: Filter and group by `matched_via`

The `matched_via` column is essential for understanding **which** payer ID column was used for matching! 🎯
