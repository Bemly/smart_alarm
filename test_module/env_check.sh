#!/system/bin/sh

echo "--- KernelSU 环境检测 ---"

# 1. 检测 CPU 架构
ARCH=$(getprop ro.product.cpu.abi)
echo "[1] CPU 架构: $ARCH"

# 2. 检测 SQLite3 是否可用 (这对你的 Gadgetbridge 提取至关重要)
SQLITE_PATH=$(which sqlite3)
if [ -z "$SQLITE_PATH" ]; then
    echo "[2] SQLite3: 未找到内置程序 (你需要自带静态二进制文件)"
else
    echo "[2] SQLite3: 已找到 -> $SQLITE_PATH"
fi

# 3. 检测 KernelSU 状态
KSU_VERSION=$(su -c 'ksu --version' 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "[3] KernelSU 版本: $KSU_VERSION"
else
    echo "[3] KernelSU: 无法通过命令行获取版本，请检查管理器"
fi

# 4. 检测 Gadgetbridge 数据库可读性
GB_DB="/data/data/nodomain.freeyourgadget.gadgetbridge/databases/Gadgetbridge"
if [ -f "$GB_DB" ]; then
    echo "[4] GB 数据库: 存在"
    # 测试读取权限
    su -c "ls -l $GB_DB"
else
    echo "[4] GB 数据库: 未找到，请确认 Gadgetbridge 已安装"
fi

echo "------------------------"

# 推送
# adb push env_check.sh /data/local/tmp/
# 赋予权限并执行
# adb shell "chmod +x /data/local/tmp/env_check.sh && su -c /data/local/tmp/env_check.sh"
# ~/code/smart_alarm/test_module ❯ adb shell "chmod +x /data/local/tmp/env_check.sh && su -c /data/local/tmp/env_check.sh"
# --- KernelSU 环境检测 ---
# [1] CPU 架构: arm64-v8a
# [2] SQLite3: 未找到内置程序 (你需要自带静态二进制文件)
# [3] KernelSU: 无法通过命令行获取版本，请检查管理器
# [4] GB 数据库: 存在
# -rw-rw---- 1 u0_a407 u0_a407 1310720 2026-02-12 22:54 /data/data/nodomain.freeyourgadget.gadgetbridge/databases/Gadgetbridge
# ------------------------