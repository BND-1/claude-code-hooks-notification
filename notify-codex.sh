#!/bin/bash

# Codex CLI 通知脚本
# Codex 完成响应时通过 notify 配置触发，JSON payload 作为单个命令行参数 ($1) 传入
# 注意：与 Claude Code hooks 不同，Codex 通过 argv 而非 stdin 传递 payload
# 支持本地通知 + 飞书推送

# ============== 配置区域 ==============
# 飞书机器人 Webhook URL（在飞书群里添加自定义机器人获取）
# 格式: https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxxxx
FEISHU_WEBHOOK=""

# ============== 解析 Codex payload ==============
# Codex 传入的 JSON 示例：
# {"type":"agent-turn-complete","last-assistant-message":"任务完成的最后一段回复"}
PAYLOAD="${1:-}"
TYPE="agent-turn-complete"
LAST_MSG="Codex 任务执行完成"

if command -v jq &> /dev/null && [ -n "$PAYLOAD" ]; then
    PARSED_TYPE=$(echo "$PAYLOAD" | jq -r '.type // ""' 2>/dev/null)
    PARSED_MSG=$(echo "$PAYLOAD" | jq -r '.["last-assistant-message"] // ""' 2>/dev/null)
    [ -n "$PARSED_TYPE" ] && TYPE="$PARSED_TYPE"
    [ -n "$PARSED_MSG" ] && LAST_MSG="$PARSED_MSG"
fi

# 按事件类型决定标题和颜色
case "$TYPE" in
    agent-turn-complete)
        TITLE="🤖 Codex 任务完成"
        COLOR="green"
        STATUS="任务执行完成"
        ;;
    *)
        TITLE="🤖 Codex 通知 ($TYPE)"
        COLOR="orange"
        STATUS="$TYPE"
        ;;
esac

# 截断过长的 assistant 消息，避免飞书卡片爆掉
TRUNC_MSG=$(echo "$LAST_MSG" | head -c 300)
[ ${#LAST_MSG} -gt 300 ] && TRUNC_MSG="${TRUNC_MSG}..."

# ============== 本地通知 ==============
send_local_notification() {
    if command -v notify-send &> /dev/null; then
        notify-send "$TITLE" "$TRUNC_MSG" --icon=dialog-information 2>/dev/null
    elif command -v terminal-notifier &> /dev/null; then
        terminal-notifier -title "$TITLE" -message "$TRUNC_MSG"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e "display notification \"$TRUNC_MSG\" with title \"$TITLE\"" 2>/dev/null
    elif command -v powershell.exe &> /dev/null; then
        powershell.exe -Command "New-BurntToastNotification -Text '$TITLE', '$TRUNC_MSG'" 2>/dev/null
    fi
}

# ============== 飞书推送 ==============
send_feishu_notification() {
    if [ -z "$FEISHU_WEBHOOK" ]; then
        return 0
    fi

    CURRENT_DIR=$(pwd)
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    if command -v jq &> /dev/null; then
        PAYLOAD_JSON=$(jq -n \
            --arg t "$TITLE" \
            --arg status "$STATUS" \
            --arg msg "$TRUNC_MSG" \
            --arg dir "$CURRENT_DIR" \
            --arg ts "$TIMESTAMP" \
            --arg col "$COLOR" \
            '{
                msg_type: "interactive",
                card: {
                    header: {
                        title: { tag: "plain_text", content: $t },
                        template: $col
                    },
                    elements: [{
                        tag: "div",
                        text: {
                            tag: "lark_md",
                            content: ("**状态**: " + $status + "\n**回复**: " + $msg + "\n**目录**: " + $dir + "\n**时间**: " + $ts)
                        }
                    }]
                }
            }')
    else
        PAYLOAD_JSON="{\"msg_type\":\"text\",\"content\":{\"text\":\"$TITLE\\n$TRUNC_MSG\\n$CURRENT_DIR $TIMESTAMP\"}}"
    fi

    curl -s -X POST "$FEISHU_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD_JSON" > /dev/null 2>&1 &
    disown
}

send_local_notification
send_feishu_notification

exit 0
