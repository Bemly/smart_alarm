#!/bin/bash

# 该文件在开发时使用，用于全量更新，适用于重构了大量文件并需要推送到手机的情况

# 定义变量
MODULE_ID="smart_alarm"
REMOTE_TMP="/data/local/tmp/${MODULE_ID}_tmp"
REMOTE_DIR="/data/adb/modules/${MODULE_ID}"

echo ">>> [1/4] Pushing files to temporary directory..."
# 清理旧的临时文件
adb shell "rm -rf $REMOTE_TMP"
# 推送当前目录到临时目录
adb push . "$REMOTE_TMP"

echo ">>> [2/4] Moving files to KernelSU module directory..."
# 确保目标目录存在
adb shell "su -c 'mkdir -p $REMOTE_DIR'"
# 移动文件 (使用 cp -rf 覆盖，确保所有新文件都被复制)
adb shell "su -c 'cp -rf $REMOTE_TMP/* $REMOTE_DIR/'"

echo ">>> [3/4] Setting permissions..."
# 1. 默认给予所有文件/目录 755 权限 (保证目录可进入，脚本可执行)
adb shell "su -c 'chmod -R 755 $REMOTE_DIR'"
# 2. 配置文件和属性文件建议设为 644 (非可执行)
adb shell "su -c 'chmod 644 $REMOTE_DIR/module.prop'"
adb shell "su -c 'chmod 644 $REMOTE_DIR/config.conf'"
# 3. 清理掉推送到手机里的部署脚本自身 (可选)
adb shell "su -c 'rm -f $REMOTE_DIR/deploy.sh'"

echo ">>> [4/4] Cleaning up..."
adb shell "rm -rf $REMOTE_TMP"

echo ">>> Deploy Complete!"
echo ">>> Tip: If this is a fresh install or service logic changed, run: adb reboot"