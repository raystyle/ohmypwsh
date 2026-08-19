#Requires -Version 7.0
# set-claude-key.ps1 - 设置 ANTHROPIC_API_KEY（用户级环境变量，不回显）
# 用法:
#   pwsh -NoProfile -File scripts\set-claude-key.ps1 -FromOmcProfile   # 从 omc GLM profile 迁移
#   pwsh -NoProfile -File scripts\set-claude-key.ps1                    # 交互式设置/轮换

param([switch]$FromOmcProfile)

$ErrorActionPreference = 'Stop'

if ($FromOmcProfile) {
    $profileFile = 'D:\Oh-My-Claude\.config\claude\profiles\GLM.json'
    if (-not (Test-Path -LiteralPath $profileFile)) { throw "未找到 omc GLM profile: $profileFile" }
    $raw = Get-Content -Raw -LiteralPath $profileFile
    if ($raw -match '"ANTHROPIC_AUTH_TOKEN"\s*:\s*"([^"]+)"') {
        $key = $Matches[1]
    } else {
        throw 'GLM profile 中未找到 ANTHROPIC_AUTH_TOKEN'
    }
    Write-Host '[OK] 已从 omc GLM profile 读取密钥（不回显）' -ForegroundColor Green
} else {
    Write-Host '=== Claude Code (GLM/bigmodel) API Key 设置 ===' -ForegroundColor Cyan
    $key = Read-Host 'ANTHROPIC_API_KEY（bigmodel.cn 密钥，形如 xxxx.yyyy）'
    $key = ($key -as [string]).Trim()
    if ($key -notmatch '^[A-Za-z0-9]+\.[A-Za-z0-9]+$') {
        Write-Host '[X] 无效的 Key（需形如 xxxx.yyyy）' -ForegroundColor Red
        exit 1
    }
}

[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $key, 'User')
$env:ANTHROPIC_API_KEY = $key
Write-Host "[OK] ANTHROPIC_API_KEY 已保存到用户级环境变量（长度 $($key.Length)，不回显）" -ForegroundColor Green
Write-Host '[HINT] 加密备份: pwsh -NoProfile -File scripts\sops-encrypt-anthropic.ps1' -ForegroundColor DarkGray
