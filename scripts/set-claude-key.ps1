#Requires -Version 7.0
# set-claude-key.ps1 - 交互式设置 ANTHROPIC_API_KEY（用户级环境变量 + SOPS 加密备份）
# 用法：pwsh -NoProfile -File scripts\set-claude-key.ps1
# 流程与 set-deepseek-key.ps1 一致：输入密钥 -> 保存用户环境变量 -> 自动调用
# sops-encrypt-anthropic.ps1 加密到 .secrets\anthropic.env.enc（回读验证，明文即删）。

Write-Host '=== Claude Code (GLM/bigmodel) API Key 设置 ===' -ForegroundColor Cyan
Write-Host '请在 open.bigmodel.cn 申请 API Key（形如 xxxx.yyyy），粘贴到下面输入框：' -ForegroundColor Yellow
$key = Read-Host 'ANTHROPIC_API_KEY'
$key = ($key -as [string]).Trim()

if ($key -notmatch '^[A-Za-z0-9]+\.[A-Za-z0-9]+$') {
    Write-Host '[X] 无效的 Key（需形如 xxxx.yyyy），未保存。' -ForegroundColor Red
} else {
    [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $key, 'User')
    $env:ANTHROPIC_API_KEY = $key
    Write-Host "[OK] 已保存到用户级环境变量 ANTHROPIC_API_KEY（长度 $($key.Length)）" -ForegroundColor Green
    Write-Host '[HINT] 新开的终端 / Claude Code 会话自动生效；settings.json 仅引用模型，不存明文。' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '[INFO] 正在加密备份到 .secrets\anthropic.env.enc ...' -ForegroundColor Cyan
    try {
        & (Join-Path $PSScriptRoot 'sops-encrypt-anthropic.ps1')
    } catch {
        Write-Host "[WARN] 加密备份失败：$_（环境变量已保存，可稍后重跑 sops-encrypt-anthropic.ps1）" -ForegroundColor Yellow
    }
}

Read-Host '按 Enter 关闭此窗口'
