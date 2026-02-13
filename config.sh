#!/system/bin/sh

# Ensure Config Exists & Load It
init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_info "Config file not found, creating default..."
        cat <<EOF > "$CONFIG_FILE"
EXPECTED_BEDTIME="23:00"
EXPECTED_WAKEUP="07:00"
EXPECTED_SLEEP_DURATION="8"
RINGTONE_PATH=""
RINGTONE_DURATION="60"
RINGTONE_INTERVAL="300"
RINGTONE_COUNT="3"
GENTLE_WAKE="true"
GENTLE_WAKE_WINDOW="20"
HR_THRESHOLD="60"
INTENSITY_THRESHOLD="60"
DETECTION_WINDOW="15"
LOG_RETENTION="3"
POLLING_MODE="dynamic"
CHECK_INTERVAL="10"
EOF
    fi
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}