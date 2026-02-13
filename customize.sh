#!/system/bin/sh

# SKIPUNZIP=1  # 如果设为1，需要手动解压。我们设为0（默认），让管理器自动解压到 $MODPATH
SKIPUNZIP=0

# 打印欢迎信息
ui_print "********************************"
ui_print "   Smart Sleep Alarm (GB)       "
ui_print "********************************"

# 这里的 $MODPATH 是模块安装后的路径 (/data/adb/modules/smart_alarm)

ui_print "- Setting permissions..."

# 1. 设置默认权限：目录 755，文件 644
set_perm_recursive "$MODPATH" 0 0 0755 0644

# 2. 给所有 shell 脚本赋予执行权限 (755)
# 包括 service.sh, config.sh, db.sh, time.sh, alarm.sh, util_log.sh
set_perm_recursive "$MODPATH" 0 0 0755 0755 "$MODPATH/*.sh"

# 3. 给二进制文件赋予执行权限
set_perm "$MODPATH/sqlite3" 0 0 0755

# 4. 确保 Log 目录存在并可写
mkdir -p "$MODPATH/Log"
set_perm_recursive "$MODPATH/Log" 0 0 0755 0666

ui_print "- Installation complete!"