# Claude Code Stop Hook - Notification Script (Windows + Feishu)
# For Windows 10/11

param(
    [string]$Title = "Claude Code",
    [string]$Message = "Task Completed!"
)

# ============== 配置区域 ==============
# 请在这里填入你的飞书机器人 Webhook URL
# 格式: https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxxxx
$FeishuWebhook = ""

# ============== 1. 桌面通知模块 ==============
try {
    # Method 1: Use BurntToast if available (recommended)
    if (Get-Module -ListAvailable -Name BurntToast) {
        Import-Module BurntToast
        New-BurntToastNotification -Text $Title, $Message -Sound 'Default'
    }
    else {
        # Method 2: Use Windows Forms (no installation required)
        Add-Type -AssemblyName System.Windows.Forms

        $notification = New-Object System.Windows.Forms.NotifyIcon
        $notification.Icon = [System.Drawing.SystemIcons]::Information
        $notification.BalloonTipTitle = $Title
        $notification.BalloonTipText = $Message
        $notification.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
        $notification.Visible = $true

        # Show notification
        $notification.ShowBalloonTip(5000)
        
        # Windows Forms icon needs a moment to process events before disposing
        # Running in background job or just brief sleep prevents script hang while keeping icon visible
        # For a simple hook, we'll just fire and forget or wait briefly if needed.
        # Note: WinForms notification might disappear instantly if script exits too fast without a loop,
        # but for a stop hook, simple execution is usually enough.
    }
}
catch {
    Write-Host "桌面通知发送失败: $_" -ForegroundColor Yellow
}

# ============== 2. 飞书推送模块 ==============
if (-not [string]::IsNullOrWhiteSpace($FeishuWebhook)) {
    try {
        # 获取当前信息
        $CurrentDir = (Get-Location).Path
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # 构建与 Linux 版本一致的消息体 (Markdown 换行在 JSON 中需用 \n)
        $ContentText = "**状态**: $Message`n**目录**: $CurrentDir`n**时间**: $Timestamp"

        # 构建 JSON Payload
        $Payload = @{
            msg_type = "interactive"
            card = @{
                header = @{
                    title = @{
                        tag = "plain_text"
                        content = "🤖 $Title"
                    }
                    template = "green"
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

        # 转换为 JSON 字符串 (处理中文编码)
        $JsonBody = $Payload | ConvertTo-Json -Depth 5 -Compress

        # 发送请求
        $Response = Invoke-RestMethod -Uri $FeishuWebhook -Method Post -Body $JsonBody -ContentType 'application/json; charset=utf-8'
        
        # Write-Host "飞书通知发送成功"
    }
    catch {
        Write-Host "飞书通知发送失败: $_" -ForegroundColor Red
    }
}

# 简短等待以确保 WinForms 图标（如果使用）能有机会渲染，然后清理
Start-Sleep -Seconds 2
if ($null -ne $notification) {
    $notification.Dispose()
}