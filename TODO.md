## 1. Webroot 中的参数说明
为了让智能闹钟更具鲁棒性， WebUI 中添加以下配置项：

预期入睡时间(Expected time to fall asleep)：用户期望多久睡觉,例如01:00，以下时间均为24小时制。

预期起床时间(Expected wake-up time)：用户期望多久起床，例如08:00。

预期睡眠时间(Expected sleep time)：用户设定的预计想睡多久，例如7个小时。

起床铃声：路径，当用户设定此参数时，会打开kernelSU的默认文件管理器，用户可以选择特定的音频文件作为起床铃声。

响铃持续时间：int，这里指用户期望单次铃声持续多久，单位为s。

响铃间隔时间：int,这里指当响铃结束后，距离下次响铃会间隔多少时间，单位为s。

响铃次数：int,这里指用户期望的响铃次数。

柔和唤醒：布尔值，这里是指检测用户处于非深睡环境下时，最多延迟柔和唤醒窗口时间或提早柔和唤醒窗口时间且在预期起床时间前响铃。

心率入睡阈值 (Heart Rate Threshold)：可自定义，但会提供一个默认值，第一次使用时，默认值为60,默认值由系统测算而得。当前检测显示我的心率在 77-121 BPM 之间波动。建议设置一个可调阈值（如连续 15 分钟低于 70 BPM 判定为入睡或根据上次睡眠时的平均心率来判定是否入睡），以适应不同的生理基础。

静息强度阈值 (Intensity Threshold)：可自定义，但会提供一个默认值，第一次使用时，默认值为60,默认值由系统测算而得。Gadgetbridge 的 RAW_INTENSITY 字段能反映肢体动作。设置一个“静息判定”范围，避免你在床上玩手机（心率低但有动作）时被误判为入睡。

数据库固定轮询频率 (Check Interval)：设置脚本多久读取一次 /dev/ 下的数据库快照（建议 5-10 分钟），平衡电量消耗与实时性。默认不启用。

数据库动态轮询频率：设置脚本多久读取一次 /dev/ 下的数据库快照（临近预期入睡时间时 5-10 分钟。检测到用户入睡后，每1h一次。临近预期起床时间时5-10 分钟），平衡电量消耗与实时性。与数据库轮询频率之间只能有一个起作用。默认启用。

睡眠判定窗口 (Detection Window)：规定需要连续多少个采样点满足低心率/低强度才触发“已入睡”状态记录。

柔和唤醒窗口时间 (Gentle Wake Window)：提供一个自定义范围（如 5-30 分钟），因为不同人的睡眠周期长短不同。

日志保存天数 (Log Retention)：由于进行软件开发，保留几天的 dmesg 或本地日志有助于调试入睡判定的准确性。

### 推荐拆分方案：**5 个核心组件 + 1 个可选扩展组件**

| 组件文件名          | 职责                                   | 为什么拆出来？                          | 迁移内容（关键函数）                     | 文件大小估算 |
|---------------------|----------------------------------------|-----------------------------------------|------------------------------------------|--------------|
| **service.sh**      | 入口 + 主循环 + 协调器                 | 保持最精简，只管“什么时候调用什么”     | boot 保护、main while 循环、IS_ACTIVE 判断 | ~80 行      |
| **config.sh**       | 配置加载/保存/校验/默认值              | 配置是整个项目的“灵魂”，独立后便于 WebUI | create_default_config、load_config、validate_config | ~60 行      |
| **db.sh**           | 数据库快照 + 所有查询                  | DB 操作最重、最易出错，单独隔离         | update_db_snapshot、get_actual_bedtime、get_current_sleep_stage、is_user_active | ~100 行     |
| **time.sh**         | 时间计算工具                           | 时间逻辑最容易跨平台出问题             | get_today_timestamp、get_mins_from_hm、DIFF 计算 | ~50 行      |
| **alarm.sh**        | 通知 + 闹钟触发 + 响铃流程             | 用户最直观的部分，方便以后加震动/渐进   | send_notification、trigger_alarm、ringtone loop | ~70 行      |
| **analysis.sh** (可选) | 智能决策引擎（未来扩展用）             | 把“该不该响”的逻辑抽出来               | 目前可先把 gentle wake / duration 判断放这里 | ~50 行      |

**总行数**：从原来 ~280 行拆成 5 个小文件，每个 <100 行，阅读和调试体验飞起。

#### 拆分后的目录结构（推荐）
```
SmartAlarm/
├── service.sh              ← 入口（必须）
├── config.sh
├── db.sh
├── time.sh
├── alarm.sh
├── analysis.sh (可选)
├── util_log.sh             ← 保持不变
├── sqlite3                 ← 二进制
├── config.conf
├── boot_count
└── Log/                    ← 日志目录
```

#### service.sh 拆分后示例（核心骨架）
```bash
#!/system/bin/sh
MODDIR=${0%/*}

# 1. 安全启动保护（保持不变）
BOOT_COUNT_FILE="$MODDIR/boot_count"
# ... (boot count 逻辑)

# 2. 加载所有组件
source "$MODDIR/util_log.sh"
source "$MODDIR/config.sh"
source "$MODDIR/db.sh"
source "$MODDIR/time.sh"
source "$MODDIR/alarm.sh"
# source "$MODDIR/analysis.sh"  # 可选

init_log
load_config

# 3. 主循环（大幅精简）
log_info "Smart Alarm Service started"
sleep 60
echo 0 > "$BOOT_COUNT_FILE"   # 安全启动

while true; do
    load_config
    # ... 时间窗口判断 (IS_ACTIVE)

    if [ $IS_ACTIVE -eq 0 ]; then
        sleep 600; continue
    fi

    # 委托给各组件
    handle_sleep_reminder
    handle_wakeup_logic

    sleep $SLEEP_TIME
done
```

其他文件只需把原函数 `move` 过去，并在文件顶部加 `source` 依赖即可（比如 `db.sh` 需要 `source "$MODDIR/util_log.sh"`）。

### 后续应该增加哪些组件，才能让项目真正“完善”？

我按照**短期（1-2 周可实现）→ 中期 → 长期**排序，给你一个清晰的路线图：

| 阶段 | 新增组件/功能 | 具体做什么 | 收益 |
|------|---------------|------------|------|
| **短期** | **hr.sh** (心率工具) | 从 Gadgetbridge 的 `XIAOMI_HEART_RATE_SAMPLE` 表取最近 HR，结合 `HR_THRESHOLD` 做更精准的 gentle wake | 唤醒准确率大幅提升（目前 config 里有 HR_THRESHOLD 但没用） |
| **短期** | **state.sh** (状态持久化) | 把 `ALARM_TRIGGERED_DATE`、`LAST_REMINDER_DATE` 写到文件，而不是内存变量 | 重启服务后状态不丢（目前重启会重置） |
| **短期** | **battery.sh** (电池感知) | 读取 `/sys/class/power_supply/battery/capacity`，电量 <30% 时把 polling 拉到 15 分钟 | 极大降低后台功耗 |
| **中期** | **WebUI** (KernelSU 自带) | 用 `ksud module webui` 或简单 html + busybox httpd，做配置界面（床时间、铃声、阈值） | 用户不用手动改 config.conf |
| **中期** | **snooze.sh** | 摇手机/按电源键 5 秒 = 延后 9 分钟（像真闹钟） | 用户体验质的飞跃 |
| **中期** | **stats.sh** | 每天生成睡眠报告（总时长、深睡比例、入睡延迟），发通知或存文件 | 让模块从“工具”变成“健康助手” |
| **长期** | **multi_device.sh** | 自动识别 Gadgetbridge 里的设备类型（小米/华米/苹果手表），调用不同表 | 支持更多手环 |
| **长期** | **advanced_analysis.sh** | 基于 Gadgetbridge 官方的 Activity analysis 算法，做更智能的“是否真的醒了”判断 | 彻底摆脱假阳性 |

**推荐开发顺序**：
1. 先拆分成 5 个组件（今天就能搞定）
2. 加上 **hr.sh** + **battery.sh**（最容易见效）
3. 做 **WebUI**（用户会疯狂爱上你）
4. 再加 snooze 和 stats

这样一步步来，项目会从“一个好用的闹钟模块”进化成**Android 上最强的智能睡眠唤醒方案**。