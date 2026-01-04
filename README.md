# Claude Code Hooks - 任务完成自动通知

让 Claude Code 在完成任务后自动发送通知提醒你，支持本地桌面通知和飞书推送。

## 功能特点

- ✅ **本地通知**：Linux/macOS/Windows 桌面弹窗提醒
- ✅ **飞书推送**：远程服务器工作时的移动端通知
- ✅ **开箱即用**：Hooks 是 Claude Code 内置功能，无需安装插件
- ✅ **简单配置**：仅需修改配置文件即可启用

## 效果展示

### Windows 桌面通知
![Windows 通知](screenshots/windows-notification.jpg)

### 飞书消息通知
![飞书通知](screenshots/feishu-notification.png)

## 快速开始

### 1. 安装脚本

```bash
# 复制脚本到 Claude Code 配置目录
cp notify.sh ~/.claude/notify.sh

# 添加执行权限
chmod +x ~/.claude/notify.sh
```

### 2. 配置飞书机器人（可选）

如果你想接收飞书通知：

1. 打开飞书，进入一个群聊（或新建一个）
2. 点击群设置 → 群机器人 → 添加机器人
3. 选择「自定义机器人」，设置名称
4. 复制生成的 Webhook 地址
5. 编辑 `~/.claude/notify.sh`，填入 Webhook：

```bash
FEISHU_WEBHOOK="https://open.feishu.cn/open-apis/bot/v2/hook/your-webhook-url"
```

### 3. 配置 Claude Code Hooks

编辑 `~/.claude/settings.json`，添加以下配置：

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/your/home/dir/.claude/notify.sh"
          }
        ]
      }
    ]
  }
}
```

**配置说明：**
- `"Stop"` — 在 Claude 完成响应时触发
- `"matcher": ""` — 空字符串表示所有情况都触发
- `"command"` — 脚本的**绝对路径**（使用 `~/.claude/notify.sh` 的绝对路径）

**获取绝对路径：**
```bash
echo ~/.claude/notify.sh
# 输出：/root/.claude/notify.sh
```

### 4. 重启 Claude Code

配置完成后，重启 Claude Code 即可生效。

### 5. 测试效果

随便问 Claude Code 一个问题，当它回复完成后，你应该能收到通知！

## 支持的通知方式

### Linux

使用 `notify-send` 发送桌面通知。

```bash
# 安装（Ubuntu/Debian）
sudo apt-get install libnotify-bin
```

### macOS

支持 `terminal-notifier` 或 `osascript`。

```bash
# 安装 terminal-notifier（可选）
brew install terminal-notifier
```

### Windows

通过 PowerShell 发送 Toast 通知（支持 WSL/Git Bash）。

### 飞书

发送富文本卡片消息，包含：
- 通知标题
- 执行状态
- 当前工作目录
- 完成时间

## 自定义配置

### 修改通知内容

编辑 `notify.sh` 中的配置区域：

```bash
TITLE="Claude Code"
MESSAGE="任务执行完成"
```

### 添加更多通知渠道

在 `notify.sh` 中添加新的函数，例如：

```bash
send_telegram_notification() {
    # 你的 Telegram Bot 逻辑
    curl -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$MESSAGE"
}

# 在脚本末尾调用
send_telegram_notification
```

## 常见问题

### Q: Hook 脚本执行失败怎么办？

A: 使用 `claude --debug` 启动，查看详细的 Hook 执行日志。

### Q: 修改配置后不生效？

A: Hooks 在启动时加载。修改后需重启 Claude Code，或使用 `/hooks` 命令重新加载。

### Q: 本地通知没有弹出？

A: 检查系统是否安装了通知工具：
- Linux: `notify-send`
- macOS: `terminal-notifier` 或 `osascript`
- Windows: PowerShell

### Q: 飞书通知收不到？

A: 检查：
1. Webhook URL 是否正确
2. 飞书机器人是否被禁用
3. 网络连接是否正常

## 更多 Hooks 创意

除了任务完成通知，你还可以实现：

### 危险命令拦截

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/safety-check.sh"
          }
        ]
      }
    ]
  }
}
```

### 自动代码格式化

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "prettier --write ."
          }
        ]
      }
    ]
  }
}
```

### 会话日志记录

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "echo \"$(date): 新会话\" >> ~/.claude/session.log"
          }
        ]
      }
    ]
  }
}
```

## Claude Code Hooks 事件类型

| 事件名称 | 触发时机 | 典型用途 |
|---------|---------|---------|
| **SessionStart** | 会话启动或恢复时 | 加载配置、初始化环境 |
| **UserPromptSubmit** | 用户提交问题时 | 注入上下文、记录日志 |
| **PreToolUse** | 工具执行前 | 拦截危险操作、审批确认 |
| **PermissionRequest** | 需要用户授权时 | 自动审批或拒绝 |
| **PostToolUse** | 工具执行后 | 记录操作、触发后续任务 |
| **Notification** | 发送通知时 | 自定义通知渠道 |
| **Stop** | Claude 完成响应时 | **发送完成通知** ⭐ |
| **SubagentStop** | 子代理完成时 | 监控子任务状态 |
| **PreCompact** | 压缩上下文前 | 保存重要信息 |

## 参考资料

- [Claude Code Hooks 官方文档](https://code.claude.com/docs/en/hooks)
- [飞书自定义机器人文档](https://open.feishu.cn/document/ukTMukTMukTM/uUTNz4SN1MjL1UzM)
- [Claude Code 完全上手指南](https://www.kdjingpai.com/en/claude-code-wanquanba/)

## License

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
