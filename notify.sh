#!/bin/bash

# Claude Code 执行完成通知脚本
# 当 Claude Code 完成响应时，通过 Stop Hook 触发此脚本
# 支持两种通知方式：本地通知 + 飞书推送

# ============== 配置区域 ==============
TITLE="Claude Code"
MESSAGE="任务执行完成"

# 飞书机器人 Webhook URL（在飞书群里添加自定义机器人获取）
# 格式: https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxxxx
FEISHU_WEBHOOK=""

# ============== 本地通知 ==============
send_local_notification() {
    # Linux 系统使用 notify-send
    if command -v notify-send &> /dev/null; then
        notify-send "$TITLE" "$MESSAGE" --icon=dialog-information 2>/dev/null
    # macOS 系统使用 terminal-notifier 或 osascript
    elif command -v terminal-notifier &> /dev/null; then
        terminal-notifier -title "$TITLE" -message "$MESSAGE"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
    # Windows (Git Bash/WSL) 使用 PowerShell
    elif command -v powershell.exe &> /dev/null; then
        powershell.exe -Command "New-BurntToastNotification -Text '$TITLE', '$MESSAGE'" 2>/dev/null
    fi
}

# ============== 飞书推送 ==============
send_feishu_notification() {
    if [ -z "$FEISHU_WEBHOOK" ]; then
        return 0
    fi

    # 获取当前目录作为项目信息
    CURRENT_DIR=$(pwd)
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # 构建飞书消息（富文本格式）
    curl -s -X POST "$FEISHU_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{
            \"msg_type\": \"interactive\",
            \"card\": {
                \"header\": {
                    \"title\": {
                        \"tag\": \"plain_text\",
                        \"content\": \"🤖 $TITLE\"
                    },
                    \"template\": \"green\"
                },
                \"elements\": [
                    {
                        \"tag\": \"div\",
                        \"text\": {
                            \"tag\": \"lark_md\",
                            \"content\": \"**状态**: $MESSAGE\n**目录**: $CURRENT_DIR\n**时间**: $TIMESTAMP\"
                        }
                    }
                ]
            }
        }" > /dev/null 2>&1
}

# ============== 执行通知 ==============
# 同时发送本地通知和飞书通知
send_local_notification
send_feishu_notification
