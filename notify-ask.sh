#!/bin/bash

# Claude Code 提问通知脚本
# 当 Claude Code 调用 AskUserQuestion 工具向用户提问时，通过 PreToolUse Hook 触发
# 用于提醒用户回到终端回答问题，避免对话长时间挂起
# 支持两种通知方式：本地通知 + 飞书推送

# ============== 配置区域 ==============
TITLE="Claude Code 等待回答"

# 飞书机器人 Webhook URL（在飞书群里添加自定义机器人获取）
# 格式: https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxxxx
FEISHU_WEBHOOK=""

# ============== 解析 Hook 输入 ==============
# PreToolUse hook 从 stdin 接收 JSON：{"tool_name":"AskUserQuestion","tool_input":{"questions":[...]}}
INPUT=$(cat)

if command -v jq &> /dev/null; then
    QUESTION=$(echo "$INPUT" | jq -r '.tool_input.questions[0].question // "Claude Code 正在等你回答问题"' 2>/dev/null)
    OPT_COUNT=$(echo "$INPUT" | jq -r '(.tool_input.questions[0].options | length) // 0' 2>/dev/null)
    Q_COUNT=$(echo "$INPUT" | jq -r '(.tool_input.questions | length) // 1' 2>/dev/null)
else
    QUESTION="Claude Code 正在等你回答问题（未安装 jq，无法解析问题文本）"
    OPT_COUNT=0
    Q_COUNT=1
fi

MESSAGE="$QUESTION"

# ============== 本地通知 ==============
send_local_notification() {
    if command -v notify-send &> /dev/null; then
        notify-send "$TITLE" "$MESSAGE" --icon=dialog-question --urgency=critical 2>/dev/null
    elif command -v terminal-notifier &> /dev/null; then
        terminal-notifier -title "$TITLE" -message "$MESSAGE"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
    elif command -v powershell.exe &> /dev/null; then
        powershell.exe -Command "New-BurntToastNotification -Text '$TITLE', '$MESSAGE'" 2>/dev/null
    fi
}

# ============== 飞书推送 ==============
send_feishu_notification() {
    if [ -z "$FEISHU_WEBHOOK" ]; then
        return 0
    fi

    CURRENT_DIR=$(pwd)
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # 使用 jq 安全构造 payload，避免问题文本里的引号/换行炸掉 JSON
    if command -v jq &> /dev/null; then
        PAYLOAD=$(jq -n \
            --arg q "$QUESTION" \
            --arg dir "$CURRENT_DIR" \
            --arg ts "$TIMESTAMP" \
            --arg opts "$OPT_COUNT" \
            --arg qc "$Q_COUNT" \
            '{
                msg_type: "interactive",
                card: {
                    header: {
                        title: { tag: "plain_text", content: "❓ Claude Code 等待你的回答" },
                        template: "orange"
                    },
                    elements: [{
                        tag: "div",
                        text: {
                            tag: "lark_md",
                            content: ("**问题**: " + $q + "\n**选项数**: " + $opts + " 个 / **问题数**: " + $qc + "\n**目录**: " + $dir + "\n**时间**: " + $ts)
                        }
                    }]
                }
            }')
    else
        # 降级：纯文本消息（不依赖 jq）
        PAYLOAD="{\"msg_type\":\"text\",\"content\":{\"text\":\"❓ Claude Code 等待你的回答\\n目录: $CURRENT_DIR\\n时间: $TIMESTAMP\"}}"
    fi

    curl -s -X POST "$FEISHU_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" > /dev/null 2>&1 &
    disown
}

# ============== 执行通知 ==============
send_local_notification
send_feishu_notification

exit 0
