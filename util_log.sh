#!/system/bin/sh

# 确保日志目录存在
init_log() {
    # MODDIR 由调用者 (service.sh) 定义
    LOG_DIR="${MODDIR}/Log"
    LATEST_LOG="${LOG_DIR}/latest.log"

    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        # 设置权限以便 WebUI (非 root) 可能读取
        chmod 755 "$LOG_DIR"
    fi
    
    if [ ! -f "$LATEST_LOG" ]; then
        touch "$LATEST_LOG"
        chmod 644 "$LATEST_LOG"
    fi
}

log_info() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$msg" >> "$LATEST_LOG"
}

rotate_log() {
    if [ -f "$LATEST_LOG" ]; then
        local timestamp=$(date '+%Y%m%d%H%M%S')
        mv "$LATEST_LOG" "${LOG_DIR}/${timestamp}.log"
        touch "$LATEST_LOG"
        chmod 644 "$LATEST_LOG"
        log_info "Log rotated. New session started."
    fi
}