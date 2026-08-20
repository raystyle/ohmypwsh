#Requires -Version 7.0
# verify-codex-handover.ps1 - Codex 交接确认脚本
# 用法：在新终端里运行 pwsh -NoProfile -File D:\ohmypwsh\scripts\verify-codex-handover.ps1

$ErrorActionPreference = 'Stop'

# 从注册表重建 PATH（等价于全新登录后的 shell 环境）
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

$envRoot = if ($env:OHMYENV_ROOT -and $env:OHMYENV_ROOT.Trim()) {
    $env:OHMYENV_ROOT.Trim().TrimEnd('\')
} elseif (Test-Path 'D:\') {
    'D:\ohmyenv'
} else {
    'C:\ohmyenv'
}
$expected = Join-Path $envRoot 'codex\bin\codex.exe'

$lock = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'env.psd1')
$expectedVersion = $lock.Tools.codex.Version
$cmd = Get-Command codex -ErrorAction SilentlyContinue

if (-not $cmd) {
    Write-Host '[X] 未找到 codex' -ForegroundColor Red
    exit 1
}

$version = (& $cmd.Source --version 2>&1 | Select-Object -First 1)

Write-Host "command : $($cmd.CommandType) $($cmd.Name)" -ForegroundColor Cyan
Write-Host "source  : $($cmd.Source)" -ForegroundColor Cyan
Write-Host "version : $version" -ForegroundColor Cyan

if ($cmd.Source -eq $expected -and $version -match [regex]::Escape($expectedVersion)) {
    Write-Host "[OK] PASS：当前终端解析到原生 codex $expectedVersion，可以在此会话继续使用" -ForegroundColor Green
    exit 0
} else {
    Write-Host '[X] FAIL：仍指向非原生（npm shim）或版本不对；请检查 PATH 顺序或开一个全新的终端' -ForegroundColor Red
    exit 1
}
