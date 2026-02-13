#!/system/bin/sh
# ==============================================================================
# Smart Alarm Service (KernelSU Module)
# Logic based on Gadgetbridge DB analysis
# ==============================================================================

# --- 1. Initialization & Environment ---

MODDIR=${0%/*}
[ -z "$MODDIR" ] && MODDIR="."

# [Safety] Boot Loop Protection
BOOT_COUNT_FILE="${0%/*}/boot_count"
[ -f "$BOOT_COUNT_FILE" ] && BOOT_COUNT=$(cat "$BOOT_COUNT_FILE") || BOOT_COUNT=0

if [ "$BOOT_COUNT" -ge 3 ]; then
    # Failsafe: Do not proceed if crashed 3 times
    exit 1
fi

# Increment counter
echo $((BOOT_COUNT + 1)) > "$BOOT_COUNT_FILE"

# Paths
CONFIG_FILE="$MODDIR/config.conf"
# LOG_FILE is now handled by util_log.sh inside Log/ directory
GB_DB_ORIG="/data/data/nodomain.freeyourgadget.gadgetbridge/databases/Gadgetbridge"
TEMP_DB="/dev/gb_snap.db"

# Load Utils
source "$MODDIR/util_log.sh"
init_log

# Locate SQLite binary (Module dir priority -> /data/local/tmp fallback)
if [ -x "$MODDIR/sqlite3" ]; then
    SQLITE="$MODDIR/sqlite3"
elif [ -x "/data/local/tmp/sqlite3" ]; then
    SQLITE="/data/local/tmp/sqlite3"
else
    log_info "ERROR: sqlite3 binary not found!"
    exit 1
fi

# Load Components
source "$MODDIR/config.sh"
source "$MODDIR/time.sh"
source "$MODDIR/db.sh"
source "$MODDIR/alarm.sh"

# Initialize Config
init_config
load_config

# State Variables
ALARM_TRIGGERED_DATE=""
LAST_REMINDER_DATE=""

# --- 3. Main Service Loop ---

log_info "Service started. Waiting for system..."
sleep 60 # Wait for boot completion & Safety buffer

# [Safety] Reset boot counter if we survived initialization
echo 0 > "$BOOT_COUNT_FILE"

while true; do
    load_config
    
    NOW_TS=$(date +%s)
    TODAY=$(date +%Y-%m-%d)
    NOW_HM=$(date +%H:%M)

    # [Optimization] Run logic only within Active Window (Bedtime - 1h to Wakeup + 1h)
    NOW_MIN=$(get_mins_from_hm "$NOW_HM")
    BED_MIN=$(get_mins_from_hm "$EXPECTED_BEDTIME")
    WAKE_MIN=$(get_mins_from_hm "$EXPECTED_WAKEUP")
    
    # Calculate Window (Modulo 1440 handles wrap-around)
    START_MIN=$(( (BED_MIN - 60 + 1440) % 1440 ))
    END_MIN=$(( (WAKE_MIN + 60) % 1440 ))
    
    IS_ACTIVE=0
    if [ $START_MIN -lt $END_MIN ]; then
        # Window within same day (e.g. 13:00 to 17:00)
        if [ $NOW_MIN -ge $START_MIN ] && [ $NOW_MIN -le $END_MIN ]; then IS_ACTIVE=1; fi
    else
        # Window crosses midnight (e.g. 22:00 to 08:00)
        if [ $NOW_MIN -ge $START_MIN ] || [ $NOW_MIN -le $END_MIN ]; then IS_ACTIVE=1; fi
    fi

    if [ $IS_ACTIVE -eq 0 ]; then
        # Outside active window: Sleep 10 minutes
        sleep 600
        continue
    fi

    # --- A. Sleep Reminder Logic ---
    if [ "$NOW_HM" == "$EXPECTED_BEDTIME" ] && [ "$LAST_REMINDER_DATE" != "$TODAY" ]; then
        update_db_snapshot || { sleep 60; continue; }
        
        if is_user_active; then
            # Check if already asleep recently (prevent false positive)
            BEDTIME_REC=$(get_actual_bedtime)
            # If no sleep record in last 2 hours
            if [ -z "$BEDTIME_REC" ] || [ $((NOW_TS - BEDTIME_REC)) -gt 7200 ]; then
                log_info "Sending sleep reminder."
                send_notification "Time to sleep! ($EXPECTED_BEDTIME)"
                LAST_REMINDER_DATE="$TODAY"
            fi
        fi
    fi

    # --- B. Wake Up Logic ---
    # Calculate Expected Wakeup Timestamp for TODAY
    # Replaced date -d with shell calculation
    EXPECTED_WAKEUP_TS=$(get_today_timestamp "$EXPECTED_WAKEUP")

    # Calculate time difference (seconds)
    DIFF=$((EXPECTED_WAKEUP_TS - NOW_TS))
    WAKE_WINDOW_SEC=$((GENTLE_WAKE_WINDOW * 60))

    # Check if we are in the Wake Up Window (From Window Start to +5 mins after target)
    # DIFF is positive if before wakeup, negative if after.
    if [ $DIFF -le $WAKE_WINDOW_SEC ] && [ $DIFF -gt -300 ]; then
        
        if [ "$ALARM_TRIGGERED_DATE" != "$TODAY" ]; then
            update_db_snapshot || { sleep 60; continue; }
            
            SHOULD_RING=0
            REASON=""

            # 1. Deadline Reached
            if [ $NOW_TS -ge $EXPECTED_WAKEUP_TS ]; then
                SHOULD_RING=1; REASON="Deadline Reached"
            fi

            # 2. Sleep Duration Reached
            if [ $SHOULD_RING -eq 0 ]; then
                ACTUAL_BEDTIME=$(get_actual_bedtime)
                if [ -n "$ACTUAL_BEDTIME" ]; then
                    SLEEP_DUR=$((NOW_TS - ACTUAL_BEDTIME))
                    # Calculate expected duration in seconds (handle float hours)
                    EXP_DUR_SEC=$(awk "BEGIN {print int($EXPECTED_SLEEP_DURATION * 3600)}")
                    if [ $SLEEP_DUR -ge $EXP_DUR_SEC ]; then
                        SHOULD_RING=1; REASON="Sleep Duration Met"
                    fi
                fi
            fi

            # 3. Gentle Wake (Light Sleep)
            if [ $SHOULD_RING -eq 0 ] && [ "$GENTLE_WAKE" == "true" ]; then
                STAGE=$(get_current_sleep_stage)
                # Assuming Stage 4 is Deep Sleep (based on your TODO)
                if [ -n "$STAGE" ] && [ "$STAGE" != "4" ]; then
                    SHOULD_RING=1; REASON="Light Sleep Detected (Stage $STAGE)"
                fi
            fi

            [ $SHOULD_RING -eq 1 ] && trigger_alarm "$REASON"
        fi
        
        # High frequency polling during wake window
        SLEEP_TIME=30
    else
        # --- C. Polling Interval ---
        if [ "$POLLING_MODE" == "fixed" ]; then
            SLEEP_TIME=$((CHECK_INTERVAL * 60))
        else
            # Dynamic: 5 mins default
            SLEEP_TIME=300
        fi
        # [Safety] Minimum polling interval 60s
        [ "$SLEEP_TIME" -lt 60 ] && SLEEP_TIME=60
    fi

    sleep $SLEEP_TIME
done