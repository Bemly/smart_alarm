#!/system/bin/sh

# --- 配置区 ---
SQLITE="/data/local/tmp/sqlite3"
REMOTE_DB="/data/data/nodomain.freeyourgadget.gadgetbridge/databases/Gadgetbridge"
LOCAL_DB="/dev/gb_snap.db"

# 1. 建立快照
su -c "cp ${REMOTE_DB}* /dev/" 
su -c "mv /dev/Gadgetbridge $LOCAL_DB"
su -c "mv /dev/Gadgetbridge-wal ${LOCAL_DB}-wal 2>/dev/null"
su -c "chmod 666 ${LOCAL_DB}*"

echo "=========================================="
echo "💓 Gadgetbridge 状态精准检测 (v2.5 Final)"
echo "=========================================="

# 2. 最新心率采样 (使用的是【秒】，不需要除以 1000)
echo "[1] 最新心率采样:"
$SQLITE $LOCAL_DB "SELECT '时间: ' || datetime(TIMESTAMP, 'unixepoch', 'localtime'), '数值: ' || HEART_RATE || ' BPM' FROM XIAOMI_ACTIVITY_SAMPLE WHERE HEART_RATE > 0 ORDER BY TIMESTAMP DESC LIMIT 1;"

# 3. 睡眠结论提取 (使用的是【毫秒】，必须除以 1000)
echo "------------------------------------------"
echo "[2] 睡眠结论记录:"
$SQLITE $LOCAL_DB "SELECT '入睡: ' || datetime(TIMESTAMP/1000, 'unixepoch', 'localtime'), '醒来: ' || datetime(WAKEUP_TIME/1000, 'unixepoch', 'localtime') FROM XIAOMI_SLEEP_TIME_SAMPLE ORDER BY TIMESTAMP DESC LIMIT 2;"

# 4. 睡眠阶段分析 (使用的是【毫秒】，必须除以 1000)
echo "------------------------------------------"
echo "[3] 睡眠细分阶段:"
$SQLITE $LOCAL_DB "SELECT '时间: ' || datetime(TIMESTAMP/1000, 'unixepoch', 'localtime'), '阶段代码: ' || STAGE FROM XIAOMI_SLEEP_STAGE_SAMPLE ORDER BY TIMESTAMP DESC LIMIT 3;"

echo "=========================================="
rm ${LOCAL_DB}*