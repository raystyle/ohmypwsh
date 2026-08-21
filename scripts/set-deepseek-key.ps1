#Requires -Version 7.0
# set-deepseek-key.ps1 - 交互式设置 DEEPSEEK_API_KEY（用户级环境变量）
# 用法：pwsh -NoProfile -File scripts\set-deepseek-key.ps1

Write-Host '=== DeepSeek API Key 设置 ===' -ForegroundColor Cyan
Write-Host '请在 platform.deepseek.com 申请 API Key（sk- 开头），粘贴到下面输入框：' -ForegroundColor Yellow
$key = Read-Host 'DeepSeek API Key' -MaskInput
$key = ($key -as [string]).Trim()

if ($key -notmatch '^sk-') {
    Write-Host '[X] 无效的 Key（必须以 sk- 开头），未保存。' -ForegroundColor Red
} else {
    [Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', $key, 'User')
    $env:DEEPSEEK_API_KEY = $key
    Write-Host "[OK] 已保存到用户级环境变量 DEEPSEEK_API_KEY（长度 $($key.Length)）" -ForegroundColor Green
    Write-Host '[HINT] 新开的终端 / Codex 会话自动生效；config.toml 仅引用 env_key，不存明文。' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '[INFO] 正在加密备份到 .secrets\deepseek.env.enc ...' -ForegroundColor Cyan
    try {
        & (Join-Path $PSScriptRoot 'sops-encrypt-deepseek.ps1')
    } catch {
        Write-Host "[WARN] 加密备份失败：$_（环境变量已保存，可稍后重跑 sops-encrypt-deepseek.ps1）" -ForegroundColor Yellow
    }
}

Read-Host '按 Enter 关闭此窗口'
