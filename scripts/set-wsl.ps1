#Requires -Version 7.0
# set-wsl.ps1 - WSL 安装/更新（microsoft/WSL 官方 x64 MSI，幂等）
# 用法: pwsh -NoProfile -File scripts\set-wsl.ps1 [-Version 2.7.12]
# 说明: 需管理员；下载官方 wsl.<version>.0.x64.msi 并静默安装。

param([string]$Version = '2.7.12')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$envRoot = Get-DefaultEnvRoot
$msiPath = Join-Path $envRoot "cache\wsl.$Version.0.x64.msi"
$msiUrl  = "https://github.com/microsoft/WSL/releases/download/$Version/wsl.$Version.0.x64.msi"

# ── 1. 提权 ──
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '[INFO] 需要管理员权限，正在提权重启本脚本...' -ForegroundColor Cyan
    $p = Start-Process (Get-Command pwsh).Source -Verb RunAs -Wait -PassThru -ArgumentList @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Version',$Version
    )
    if ($p.ExitCode -ne 0) { throw "提权安装失败 exit=$($p.ExitCode)" }
    return
}

# ── 2. 下载官方 MSI ──
if (-not (Test-Path -LiteralPath $msiPath)) {
    Write-Host "[INFO] 下载 $msiUrl" -ForegroundColor Cyan
    Save-ReleaseAsset -Url $msiUrl -OutFile $msiPath
}
Write-Host "[OK] MSI 就绪: $msiPath ($((Get-Item $msiPath).Length) bytes)" -ForegroundColor Green

# ── 3. 静默安装 / 更新 ──
$p = Start-Process msiexec.exe -ArgumentList @('/i', $msiPath, '/qn', '/norestart') -Wait -PassThru
if ($p.ExitCode -notin @(0, 3010)) { throw "WSL MSI 安装失败 exit=$($p.ExitCode)" }

# ── 4. 校验 ──
$ver = (& wsl.exe --version 2>&1 | Out-String)
Write-Host ($ver -replace "`0", '') -ForegroundColor Green
Write-Host '[完成] WSL 安装/更新就绪。' -ForegroundColor Cyan
