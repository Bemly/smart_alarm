#!/system/bin/sh

update_db_snapshot() {
    # [Safety] DB Size Check (>200MB)
    if [ -f "$GB_DB_ORIG" ]; then
        local db_size=$(stat -c %s "$GB_DB_ORIG")
        if [ "$db_size" -gt 200000000 ]; then
            log_info "DB too big (${db_size} bytes), skipping snapshot."
            return 1
        fi
    fi

    # Copy DB to /dev/ (RAM) to prevent locking the main DB
    cp "$GB_DB_ORIG" "$TEMP_DB"
    [ -f "${GB_DB_ORIG}-wal" ] && cp "${GB_DB_ORIG}-wal" "${TEMP_DB}-wal"
    [ -f "${GB_DB_ORIG}-shm" ] && cp "${GB_DB_ORIG}-shm" "${TEMP_DB}-shm"
    chmod 666 "${TEMP_DB}"*
}

get_actual_bedtime() {
    # Returns timestamp (seconds) of the last sleep start
    # DB stores milliseconds, so we divide by 1000
    $SQLITE "$TEMP_DB" "SELECT TIMESTAMP/1000 FROM XIAOMI_SLEEP_TIME_SAMPLE ORDER BY TIMESTAMP DESC LIMIT 1;"
}

get_current_sleep_stage() {
    # Returns the latest sleep stage code
    $SQLITE "$TEMP_DB" "SELECT STAGE FROM XIAOMI_SLEEP_STAGE_SAMPLE ORDER BY TIMESTAMP DESC LIMIT 1;"
}

is_user_active() {
    # Check if user had intensity > 0 in the last 20 mins (1200s)
    # Uses INTENSITY_THRESHOLD from config (default 60 if not set)
    local threshold=${INTENSITY_THRESHOLD:-60}
    local now_sec=$(date +%s)
    local check_start=$((now_sec - 1200))
    local count=$($SQLITE "$TEMP_DB" "SELECT COUNT(*) FROM XIAOMI_ACTIVITY_SAMPLE WHERE TIMESTAMP > $check_start AND RAW_INTENSITY > $threshold;")
    [ "$count" -gt 0 ]
}