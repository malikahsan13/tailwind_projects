@echo off
REM ============================================================================
REM Insurance Firm Sync - Complete Execution Script (Windows)
REM ============================================================================
REM Usage: run_sync.bat database_name username [password]
REM Example: run_sync.bat mydb root mypassword
REM ============================================================================

setlocal enabledelayedexpansion

SET DB_NAME=%1
SET DB_USER=%2
SET DB_PASS=%3

IF "%DB_NAME%"=="" (
    SET DB_NAME=your_database_name
)

IF "%DB_USER%"=="" (
    SET DB_USER=root
)

echo ========================================================================
echo      Insurance Firm Sync - Complete Execution
echo ========================================================================
echo.
echo Database: %DB_NAME%
echo Username: %DB_USER%
echo.

REM Confirm backup
set /p BACKUP="Have you created a backup? (y/n): "
if /i not "%BACKUP%"=="y" (
    echo.
    echo ERROR: Please create a backup first!
    echo Run: CREATE TABLE insurance_firm_backup_YYYYMMDD AS SELECT * FROM insurance_firm;
    pause
    exit /b 1
)

echo.
echo ========================================================================
echo Starting sync process...
echo ========================================================================
echo.

REM Array of scripts in order
set SCRIPTS[1]=step1_setup\01_add_columns.sql
set SCRIPTS[2]=step1_setup\02_verify_columns.sql
set SCRIPTS[3]=step2_check\01_data_quality.sql
set SCRIPTS[4]=step2_check\02_predict_matches.sql
set SCRIPTS[5]=step2_check\03_patient_impact.sql
set SCRIPTS[6]=step3_sync\01_update_matching.sql
set SCRIPTS[7]=step3_sync\02_delete_garbage.sql
set SCRIPTS[8]=step3_sync\03_insert_new.sql
set SCRIPTS[9]=step4_verify\01_sync_summary.sql
set SCRIPTS[10]=step4_verify\02_data_completeness.sql
set SCRIPTS[11]=step4_verify\03_patient_integrity.sql
set SCRIPTS[12]=step4_verify\04_cleanup.sql

set TOTAL=12
set CURRENT=0

REM Run each script
for /l %%i in (1,1,%TOTAL%) do (
    set /a CURRENT+=1
    set SCRIPT=!SCRIPTS[%%i]!

    echo [!CURRENT!/!TOTAL!] Running: !SCRIPT!
    echo.

    if exist "!SCRIPT!" (
        if "%DB_PASS%"=="" (
            mysql -u %DB_USER% -p %DB_NAME% < "!SCRIPT!"
        ) else (
            mysql -u %DB_USER% -p%DB_PASS% %DB_NAME% < "!SCRIPT!"
        )

        if !errorlevel! equ 0 (
            echo [SUCCESS]
        ) else (
            echo [ERROR] in !SCRIPT!
            echo Stopping execution...
            pause
            exit /b 1
        )
    ) else (
        echo [ERROR] File not found: !SCRIPT!
        pause
        exit /b 1
    )

    echo.

    REM Pause after step 5 (pre-sync analysis)
    if !CURRENT!==5 (
        echo ========================================================================
        echo PRE-SYNC ANALYSIS COMPLETE
        echo ========================================================================
        echo Review the output above before proceeding
        echo.
        pause
        echo.
    )
)

echo.
echo ========================================================================
echo           SYNC PROCESS COMPLETE
echo ========================================================================
echo.
echo Next steps:
echo   1. Review the output above
echo   2. Check monitoring views:
echo      SELECT * FROM v_insurance_firm_sync_dashboard;
echo      SELECT * FROM v_insurance_firm_needs_review;
echo   3. See README.md for verification queries
echo.
pause
