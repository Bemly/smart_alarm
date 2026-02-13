#!/bin/bash

# 该文件在开发时使用，用于增量更新，适用于推送单个文件到手机的情况

FILE=$1
MODULE_PATH="/data/adb/modules/smart_alarm"
TMP_PATH="/data/local/tmp"

if [ -z "$FILE" ]; then
    echo "Usage: ./update.sh <filename>"
    echo "Example: ./update.sh service.sh"
    exit 1
fi

echo ">>> Updating $FILE ..."

# 1. 推送到临时目录
adb push "$FILE" "$TMP_PATH/$FILE"

# 2. 移动到模块目录 (使用 root)
adb shell "su -c 'mv $TMP_PATH/$FILE $MODULE_PATH/$FILE'"

# 3. 权限修复 & 重启逻辑
if [[ "$FILE" == "service.sh" || "$FILE" == "util.sh" ]]; then
    echo ">>> Fixing permissions (+x)..."
    adb shell "su -c 'chmod 755 $MODULE_PATH/$FILE'"

    echo ">>> Restarting Service..."
    # 杀掉旧服务，重置启动计数器(防止触发逃生机制)，后台启动新服务
    adb shell "su -c 'pkill -f service.sh; echo 0 > $MODULE_PATH/boot_count; nohup $MODULE_PATH/service.sh > /dev/null 2>&1 &'"
    echo ">>> Service restarted!"
elif [[ "$FILE" == "index.html" ]]; then
    # Webroot 文件通常不需要执行权限，但为了保险给个读权限
    adb shell "su -c 'chmod 644 $MODULE_PATH/$FILE'"
    echo ">>> WebUI updated. Refresh your browser."
else
    # Config 或其他文件
    adb shell "su -c 'chmod 644 $MODULE_PATH/$FILE'"
    echo ">>> File updated."
fi