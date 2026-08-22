#Requires -Version 7.0
# set-wsl-distro.ps1 - WSL 镜像导入/部署（参考 D:\ohmywsl2\scripts\import.ps1，EnvRoot 派生）
# 用法: pwsh -NoProfile -File scripts\set-wsl-distro.ps1 [-Image <路径|URL>] [-Distro ohmywsl] [-Force] [-SkipWslConfig]
# 说明: 导入官方 .wsl 产物为 WSL distro；默认镜像目录 D:\ohmyenv\images\wsl，回退参考 D:\ohmywsl2\images。

param(
    [string]$Image = '',
    [string]$Distro = 'ohmywsl',
    [string]$InstallDir = '',
    [switch]$Force,
    [switch]$SkipWslConfig
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$envRoot   = Get-DefaultEnvRoot
$imagesDir = Join-Path $envRoot 'images\wsl'

function Write-Info { param([string]$m) Write-Host "[INFO]  $m" -ForegroundColor Cyan }
function Write-Ok   { param([string]$m) Write-Host "[OK]    $m" -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host "[WARN]  $m" -ForegroundColor Yellow }

# ── 1. 选择镜像 ──
if (-not $Image) {
    $candidates = @()
    $candidates += Get-ChildItem "$imagesDir\*.wsl" -ErrorAction SilentlyContinue
    $candidates += Get-ChildItem 'D:\ohmywsl2\images\*.wsl' -ErrorAction SilentlyContinue
    $candidates = @($candidates | Sort-Object LastWriteTime -Descending)
    if (-not $candidates) { throw "未找到 .wsl 镜像（$imagesDir 或 D:\ohmywsl2\images）" }
    $Image = $candidates[0].FullName
}

if ($Image -match '^https?://') {
    $leaf  = Split-Path ($Image -split '[?#]')[0] -Leaf
    $local = Join-Path $envRoot "cache\wsl\$leaf"
    if (-not (Test-Path -LiteralPath $local)) {
        Write-Info "下载镜像 $Image ..."
        Save-ReleaseAsset -Url $Image -OutFile $local
    }
    $Image = $local
}

if (-not (Test-Path -LiteralPath $Image)) { throw "镜像文件不存在: $Image" }
Write-Info "导入镜像: $Image ($([math]::Round((Get-Item $Image).Length/1MB,1)) MB)"

# ── 2. 同名冲突 ──
# wsl -l -q 输出为 UTF-16LE，需临时切控制台解码编码，否则字符串含 NUL、.Trim() 去不掉导致判定恒错
$prevEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode
$existing = wsl -l -q 2>$null | Where-Object { $_.Trim() -eq $Distro }
[Console]::OutputEncoding = $prevEncoding
if ($existing) {
    if (-not $Force) { throw "已存在同名 distro $Distro，使用 -Force 覆盖" }
    Write-Warn "已存在 $Distro，-Force 覆盖（旧环境将被销毁）"
    wsl --shutdown | Out-Null
    Start-Sleep -Seconds 2
    wsl --unregister $Distro 2>$null | Out-Null
    Start-Sleep -Seconds 2
}

# ── 3. 自适应 .wslconfig（可选）──
if (-not $SkipWslConfig) {
    $hostRamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $hostCpu   = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    $memoryGB  = [math]::Max([math]::Floor($hostRamGB * 0.5), 4)
    $cpuRaw    = [math]::Floor($hostCpu * 0.5)
    $cpu       = [math]::Max(($cpuRaw - ($cpuRaw % 2)), 2)
    $cfgPath   = Join-Path $env:USERPROFILE '.wslconfig'
    if (Test-Path $cfgPath) { Copy-Item $cfgPath "$cfgPath.bak" -Force }
    $content = @"
[wsl2]
memory=${memoryGB}GB
processors=${cpu}
swap=8GB
networkingMode=mirrored
dnsTunneling=false
autoProxy=true
firewall=true
"@
    Set-Content -Path $cfgPath -Value $content -Encoding UTF8
    Write-Ok ".wslconfig 已更新（${memoryGB}GB / ${cpu} 核 / mirrored）"
    wsl --shutdown | Out-Null
    Start-Sleep -Seconds 2
}

# ── 4. 导入 ──
if (-not $InstallDir) { $InstallDir = Join-Path $envRoot "wsl\$Distro" }
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Write-Info "导入中（vhdx 目标: $InstallDir）..."
$null = wsl --import $Distro $InstallDir $Image --version 2
if ($LASTEXITCODE -ne 0) { throw "导入失败 exit=$LASTEXITCODE" }
Write-Ok "导入完成: $Distro"

# ── 5. 时区 ──
$null = wsl -d $Distro -u root bash -c "timedatectl set-timezone Asia/Singapore 2>/dev/null; true" 2>$null
Write-Ok "已启动 + 时区 Asia/Singapore"

Write-Host ''
Write-Host "[完成] 进入: wsl -d $Distro" -ForegroundColor Cyan
