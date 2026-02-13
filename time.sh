#!/system/bin/sh

# [Helper] Calculate timestamp for HH:MM today without date -d
get_today_timestamp() {
    local target_hm=$1
    local h=${target_hm%:*}
    local m=${target_hm#*:}
    
    # Get current time components (strip leading zeros via 10# base)
    local now_sec=$(date +%s)
    local cur_h=$(date +%H)
    local cur_m=$(date +%M)
    local cur_s=$(date +%S)
    
    # Calculate seconds since midnight
    local sec_since_midnight=$(( 10#$cur_h * 3600 + 10#$cur_m * 60 + 10#$cur_s ))
    local midnight_sec=$(( now_sec - sec_since_midnight ))
    
    # Calculate target timestamp
    echo $(( midnight_sec + 10#$h * 3600 + 10#$m * 60 ))
}

# [Helper] Convert HH:MM to minutes from midnight (0-1439)
get_mins_from_hm() {
    local hm=$1
    local h=${hm%:*}
    local m=${hm#*:}
    echo $(( 10#$h * 60 + 10#$m ))
}