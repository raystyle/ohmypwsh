#Requires -Version 7.0
# set-gsudo-config.ps1 - gsudo sudo 别名（sudo.exe shim，幂等）
# 用法: pwsh -NoProfile -File scripts\set-gsudo-config.ps1
# 前置: 先 `ohmyenv.ps1 deploy gsudo`

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')   # 重建 PATH + Get-DefaultEnvRoot

$envRoot   = Get-DefaultEnvRoot
$gsudoDir  = Join-Path $envRoot 'gsudo'
$gsudoExe  = Join-Path $gsudoDir 'gsudo.exe'
$sudoExe   = Join-Path $gsudoDir 'sudo.exe'

if (-not (Test-Path -LiteralPath $gsudoExe)) {
    throw "未找到 gsudo: $gsudoExe`n请先运行: pwsh -NoProfile -File scripts\ohmyenv.ps1 deploy gsudo"
}

$needCopy = $false
if (Test-Path -LiteralPath $sudoExe) {
    $src = Get-Item -LiteralPath $gsudoExe
    $dst = Get-Item -LiteralPath $sudoExe
    if ($src.Length -ne $dst.Length) { $needCopy = $true }
} else {
    $needCopy = $true
}

if ($needCopy) {
    Copy-Item -LiteralPath $gsudoExe -Destination $sudoExe -Force
    Write-Host "[OK] sudo.exe 已创建（gsudo.exe 同源 shim）: $sudoExe" -ForegroundColor Green
} else {
    Write-Host '[INFO] sudo.exe 已就绪' -ForegroundColor DarkGray
}

# Windows 11 / Server 2025 自带 sudo（system32\sudo.exe），PATH 顺序（Machine 在前）会优先命中；
# 若本机 sudo 并非解析到 gsudo，给出提示（仍可用 gsudo 命令直接使用）。
$resolved = (Get-Command sudo -ErrorAction SilentlyContinue).Source
if ($resolved -and $resolved -ne $sudoExe) {
    Write-Host "[WARN] 本机 sudo 解析到 $resolved（Windows 内置 sudo），未命中 gsudo。" -ForegroundColor Yellow
    Write-Host '       请直接使用 gsudo 命令；如需 sudo 指向 gsudo，需在 profile 加别名或调整 PATH 顺序。' -ForegroundColor Yellow
}

Write-Host '[完成] sudo 命令就绪：首次执行弹一次 UAC，随后一段时间内免重复授权。' -ForegroundColor Cyan
