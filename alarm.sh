#!/system/bin/sh

send_notification() {
    cmd notification post -S bigtext -t "Smart Alarm" "Tag" "$1" >/dev/null 2>&1
}

trigger_alarm() {
    log_info "!!! ALARM TRIGGERED: $1 !!!"
    
    # Wake up screen
    input keyevent KEYCODE_WAKEUP
    
    local count=0
    while [ $count -lt $RINGTONE_COUNT ]; do
        log_info "Ringing ($((count+1))/$RINGTONE_COUNT)..."
        
        if [ -n "$RINGTONE_PATH" ] && [ -f "$RINGTONE_PATH" ]; then
            # Try to play specific file via Intent
            am start -a android.intent.action.VIEW -d "file://$RINGTONE_PATH" -t "audio/*" >/dev/null 2>&1
        else
            # Fallback to system alarm intent
            am start -a android.intent.action.SET_ALARM >/dev/null 2>&1
        fi
        
        sleep $RINGTONE_DURATION
        
        # Wait for interval if not the last ring
        if [ $count -lt $((RINGTONE_COUNT - 1)) ]; then
            sleep $RINGTONE_INTERVAL
        fi
        count=$((count + 1))
    done
    
    ALARM_TRIGGERED_DATE=$(date +%Y-%m-%d)
    
    # Rotate log after wakeup session is complete
    rotate_log
}