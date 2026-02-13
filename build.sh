#!/bin/bash

# 该文件用于生成zip文件

# 获取版本号
VERSION=$(grep "version=" module.prop | cut -d'=' -f2)
ZIP_NAME="SmartAlarm_${VERSION}.zip"

echo ">>> Packaging $ZIP_NAME ..."

# 移除旧的 zip
rm -f "$ZIP_NAME"

# 打包命令
# -r: 递归
# -x: 排除指定文件
zip -r "$ZIP_NAME" . \
    -x "*.git*" \
    -x ".gitignore" \
    -x "build.sh" \
    -x "dev_*" \
    -x "test_module*" \
    -x "TODO.md" \
    -x "boot_count" \
    -x "Log/*" \
    -x "*.zip" \
    -x ".DS_Store"

echo ">>> Done!"
echo ">>> File created: $(pwd)/$ZIP_NAME"
echo ">>> You can now upload this zip to KernelSU APP or GitHub Releases."