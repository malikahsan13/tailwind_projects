#!/bin/bash
# ============================================================================
# Insurance Firm Sync - Complete Execution Script
# ============================================================================
# Usage: ./run_sync.sh <database_name> <username> [password]
# Example: ./run_sync.sh mydb root mypassword
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get parameters
DB_NAME=${1:-"your_database_name"}
DB_USER=${2:-"root"}
DB_PASS=${3:-""}

# MySQL command
if [ -n "$DB_PASS" ]; then
    MYSQL="mysql -u $DB_USER -p$DB_PASS $DB_NAME"
else
    MYSQL="mysql -u $DB_USER -p $DB_NAME"
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Insurance Firm Sync - Complete Execution              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Database: ${YELLOW}$DB_NAME${NC}"
echo -e "Username: ${YELLOW}$DB_USER${NC}"
echo ""

# Confirm before starting
read -p "$(echo -e ${YELLOW}Have you created a backup? (y/n): ${NC})" -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}✗ Please create a backup first!${NC}"
    echo "Run: CREATE TABLE insurance_firm_backup_YYYYMMDD AS SELECT * FROM insurance_firm;"
    exit 1
fi

# Array of scripts in order
declare -a SCRIPTS=(
    "step1_setup/01_add_columns.sql"
    "step1_setup/02_verify_columns.sql"
    "step2_check/01_data_quality.sql"
    "step2_check/02_predict_matches.sql"
    "step2_check/03_patient_impact.sql"
    "step3_sync/01_update_matching.sql"
    "step3_sync/02_delete_garbage.sql"
    "step3_sync/03_insert_new.sql"
    "step4_verify/01_sync_summary.sql"
    "step4_verify/02_data_completeness.sql"
    "step4_verify/03_patient_integrity.sql"
    "step4_verify/04_cleanup.sql"
)

# Total number of scripts
TOTAL=${#SCRIPTS[@]}
CURRENT=0

# Run each script
for SCRIPT in "${SCRIPTS[@]}"; do
    CURRENT=$((CURRENT + 1))

    echo -e "${BLUE}[$CURRENT/$TOTAL] Running: $SCRIPT${NC}"

    if [ -f "$SCRIPT" ]; then
        $MYSQL < "$SCRIPT"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Success${NC}"
        else
            echo -e "${RED}✗ Error in $SCRIPT${NC}"
            echo -e "${RED}Stopping execution...${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ File not found: $SCRIPT${NC}"
        exit 1
    fi

    # Pause after critical steps
    if [ "$CURRENT" -eq 5 ]; then
        echo ""
        echo -e "${YELLOW}=== PRE-SYNC ANALYSIS COMPLETE ===${NC}"
        echo -e "${YELLOW}Review the output above before proceeding${NC}"
        read -p "Press Enter to continue to sync execution..."
        echo ""
    fi

    echo ""
done

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✓ SYNC PROCESS COMPLETE                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Review the output above"
echo -e "  2. Check monitoring views:"
echo -e "     ${BLUE}SELECT * FROM v_insurance_firm_sync_dashboard;${NC}"
echo -e "     ${BLUE}SELECT * FROM v_insurance_firm_needs_review;${NC}"
echo -e "  3. See README.md for verification queries"
echo ""
