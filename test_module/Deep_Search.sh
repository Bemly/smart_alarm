#!/system/bin/sh
SQLITE="/data/local/tmp/sqlite3"
DB_PATH="/data/data/nodomain.freeyourgadget.gadgetbridge/databases/Gadgetbridge"

echo "--- 正在扫描所有小米相关的数据表行数 ---"
# 获取所有以 XIAOMI 开头的表，并统计行数
TABLES=$(su -c "$SQLITE $DB_PATH \"SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'XIAOMI_%';\"")

for table in $TABLES; do
    COUNT=$(su -c "$SQLITE $DB_PATH \"SELECT COUNT(*) FROM $table;\"")
    if [ "$COUNT" -gt 0 ]; then
        echo "✅ 表 [$table]: 发现 $COUNT 条数据"
    else
        echo "  - 表 [$table]: 为空"
    fi
done

echo "----------------------------------------"
echo "🔍 尝试从每日摘要表获取睡眠数据:"
# 尝试查询每日摘要
su -c "$SQLITE $DB_PATH \"SELECT '日期: ' || DATE, '总时长: ' || (SLEEP_DURATION/60) || '小时' FROM XIAOMI_DAILY_SUMMARY_SAMPLE ORDER BY DATE DESC LIMIT 1;\""