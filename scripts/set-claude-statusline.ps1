#Requires -Version 7.0
# set-claude-statusline.ps1 - Claude Code 状态栏配置（幂等合并 statusLine 块到 ~/.claude/settings.json）
# 保留既有 env / permissions 等配置，仅覆盖 statusLine。
# 用法: pwsh -NoProfile -File scripts\set-claude-statusline.ps1
#       可选: -StatusLineCommand '<命令>' -Padding <0|1>

param(
    [string]$StatusLineCommand = '"C:/Program Files/PowerShell/7/pwsh.exe" -NoProfile -File D:/ohmypwsh/scripts/claude-statusline.ps1',
    [int]$Padding = 0
)

$ErrorActionPreference = 'Stop'

$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
New-Item -ItemType Directory -Path (Split-Path $settingsPath -Parent) -Force | Out-Null

if (Test-Path -LiteralPath $settingsPath) {
    $settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
} else {
    $settings = [pscustomobject]@{}
}
$obj = [ordered]@{}
$settings.PSObject.Properties | ForEach-Object { $obj[$_.Name] = $_.Value }

$obj['statusLine'] = [ordered]@{
    type    = 'command'
    command = $StatusLineCommand
    padding = $Padding
}

$json = $obj | ConvertTo-Json -Depth 12
if (Test-Path -LiteralPath $settingsPath) {
    $old = (Get-Content -Raw -LiteralPath $settingsPath).Trim()
    if ($old -eq $json.Trim()) {
        Write-Host '[INFO] settings.json statusLine 已是最新，跳过' -ForegroundColor DarkGray
        exit 0
    }
    Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak-$(Get-Date -Format 'yyyyMMddHHmmss')" -Force
}
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Host "[OK] 已写入 statusLine: $settingsPath" -ForegroundColor Green
Write-Host "  command : $StatusLineCommand" -ForegroundColor DarkGray
Write-Host "  padding : $Padding" -ForegroundColor DarkGray
