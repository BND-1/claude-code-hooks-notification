# Claude Code PreToolUse Hook - AskUserQuestion Notification (Windows + Feishu)
# 当 Claude Code 调用 AskUserQuestion 工具向用户提问时触发
# 用于提醒用户回到终端回答问题，避免对话长时间挂起

# ============== 配置区域 ==============
# 请在这里填入你的飞书机器人 Webhook URL
# 格式: https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxxxx
$FeishuWebhook = ""

$Title = "Claude Code 等待回答"
$DefaultMessage = "Claude Code 正在等你回答问题"

# ============== 解析 Hook 输入 ==============
# PreToolUse hook 从 stdin 接收 JSON
$InputJson = [Console]::In.ReadToEnd()
$Question = $DefaultMessage
$OptCount = 0
$QCount = 1

try {
    if (-not [string]::IsNullOrWhiteSpace($InputJson)) {
        $Data = $InputJson | ConvertFrom-Json
        if ($Data.tool_input.questions -and $Data.tool_input.questions.Count -gt 0) {
            $FirstQ = $Data.tool_input.questions[0]
            if ($FirstQ.question) { $Question = $FirstQ.question }
            if ($FirstQ.options) { $OptCount = $FirstQ.options.Count }
            $QCount = $Data.tool_input.questions.Count
        }
    }
}
catch {
    # 解析失败保持默认值
}

$Message = $Question

# ============== 1. 桌面通知模块 ==============
try {
    if (Get-Module -ListAvailable -Name BurntToast) {
        Import-Module BurntToast
        New-BurntToastNotification -Text $Title, $Message -Sound 'Default'
    }
    else {
        Add-Type -AssemblyName System.Windows.Forms

        $notification = New-Object System.Windows.Forms.NotifyIcon
        $notification.Icon = [System.Drawing.SystemIcons]::Question
        $notification.BalloonTipTitle = $Title
        $notification.BalloonTipText = $Message
        $notification.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
        $notification.Visible = $true

        $notification.ShowBalloonTip(5000)
    }
}
catch {
    Write-Host "桌面通知发送失败: $_" -ForegroundColor Yellow
}

# ============== 2. 飞书推送模块 ==============
if (-not [string]::IsNullOrWhiteSpace($FeishuWebhook)) {
    try {
        $CurrentDir = (Get-Location).Path
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        $ContentText = "**问题**: $Question`n**选项数**: $OptCount 个 / **问题数**: $QCount`n**目录**: $CurrentDir`n**时间**: $Timestamp"

        $Payload = @{
            msg_type = "interactive"
            card = @{
                header = @{
                    title = @{
                        tag = "plain_text"
                        content = "❓ Claude Code 等待你的回答"
                    }
                    template = "orange"
                }
                elements = @(
                    @{
                        tag = "div"
                        text = @{
                            tag = "lark_md"
                            content = $ContentText
                        }
                    }
                )
            }
        }

        $JsonBody = $Payload | ConvertTo-Json -Depth 5 -Compress
        $Response = Invoke-RestMethod -Uri $FeishuWebhook -Method Post -Body $JsonBody -ContentType 'application/json; charset=utf-8'
    }
    catch {
        Write-Host "飞书通知发送失败: $_" -ForegroundColor Red
    }
}

Start-Sleep -Seconds 2
if ($null -ne $notification) {
    $notification.Dispose()
}
