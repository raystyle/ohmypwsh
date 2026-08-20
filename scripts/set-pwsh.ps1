#Requires -Version 5.1
# set-pwsh.ps1 - PowerShell 7 一键幂等安装/升级（PS5.1 兼容，人类自行运行）
# 为什么独立运行：pwsh 不能安全自更新——当前 pwsh 会话正在使用自己的 exe/dll，
# MSI 替换会导致文件占用/会话破坏。因此本脚本用 powershell.exe（PS5.1）启动。
#
# 用法（独立终端运行）:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\ohmypwsh\scripts\set-pwsh.ps1
#
# 逻辑：检测系统已装 PowerShell 7 -> 决定 新装 / 升级 / 跳过（幂等）。

param(
    [string]$Version = '7.6.5'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$target  = [version]$Version
$tag     = "v$Version"
$msiName = "PowerShell-$Version-win-x64.msi"
$msiUrl  = "https://github.com/PowerShell/PowerShell/releases/download/$tag/$msiName"
$envRoot  = if ($env:OHMYENV_ROOT -and $env:OHMYENV_ROOT.Trim()) { $env:OHMYENV_ROOT.Trim().TrimEnd('\') } elseif (Test-Path 'D:\') { 'D:\ohmyenv' } else { 'C:\ohmyenv' }
$cacheDir = Join-Path $envRoot 'cache'
$msiPath  = Join-Path $cacheDir $msiName

Write-Host "===== PowerShell 7 一键幂等安装/升级（目标 $Version）=====" -ForegroundColor Cyan

# ── 1. 检测系统已装 PowerShell 7 ──
$probe = @(
    (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\PowerShell\7\pwsh.exe')
)
$cur = $null
$curPath = $null
foreach ($p in $probe) {
    if (Test-Path -LiteralPath $p) {
        $raw = (& $p -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null | Select-Object -First 1)
        if ($raw) {
            $cur = [version]($raw.ToString().Trim())
            $curPath = $p
            break
        }
    }
}

if ($cur) {
    Write-Host "[INFO] 检测到 PowerShell 7 $cur @ $curPath"
    if ($cur -ge $target) {
        Write-Host "[OK] 已是最新或更高版本，跳过" -ForegroundColor Green
        exit 0
    }
    Write-Host "[INFO] 需要升级: $cur -> $Version" -ForegroundColor Yellow
} else {
    Write-Host "[INFO] 未检测到 PowerShell 7，执行全新安装 $Version" -ForegroundColor Yellow
}

# ── 2. 管理员检查（per-machine MSI 需要管理员；非管理员自动提权重启本脚本）──
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[INFO] 非管理员，正在提权重启脚本..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit 0
}

# PS5.1 兼容的下载器（aria2 主通道 → curl → Invoke-WebRequest 兜底）
function Save-ReleaseAssetPs5 {
    param([Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)][string]$OutFile)
    $outDir = Split-Path -Parent $OutFile
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    if (Test-Path -LiteralPath $OutFile) {
        Write-Host "[INFO] 已有缓存，复用: $OutFile" -ForegroundColor DarkGray
        return
    }
    $aria2 = (Get-Command aria2c.exe -ErrorAction SilentlyContinue).Source
    if ($aria2) {
        $outName = Split-Path -Leaf $OutFile
        & $aria2 -x 16 -s 16 -k 1M --file-allocation=none --auto-file-renaming=false --allow-overwrite=true --summary-interval=0 --console-log-level=warn --connect-timeout=20 --timeout=60 --max-tries=3 --retry-wait=5 -d $outDir -o $outName $Url
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $OutFile)) {
            Write-Host "[OK] 已下载（aria2）: $OutFile" -ForegroundColor Green
            return
        }
        Write-Host "[WARN] aria2 下载失败，改用 curl" -ForegroundColor Yellow
    }
    $curl = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source
    if ($curl) {
        & $curl -L --fail --retry 5 --retry-delay 3 --connect-timeout 20 -sS -o $OutFile $Url
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $OutFile)) {
            Write-Host "[OK] 已下载（curl）: $OutFile" -ForegroundColor Green
            return
        }
        Write-Host "[WARN] curl 下载失败，改用 Invoke-WebRequest 兜底" -ForegroundColor Yellow
    }
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -TimeoutSec 600
    Write-Host "[OK] 已下载（Invoke-WebRequest）: $OutFile" -ForegroundColor Green
}

# ── 3. 下载 MSI（缓存命中则复用）──
if (-not (Test-Path -LiteralPath $msiPath)) {
    Write-Host "[INFO] 下载 $msiUrl ..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    Save-ReleaseAssetPs5 -Url $msiUrl -OutFile $msiPath
}
Write-Host "[OK] MSI: $msiPath"

# ── 4. 静默安装/升级（UpgradeCode 自动替换旧版；DISABLE_TELEMETRY=1 关遥测）──
Write-Host "[INFO] msiexec 静默安装/升级..." -ForegroundColor Cyan
$log = Join-Path $env:TEMP "pwsh-$Version-install.log"
$p = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$msiPath`" /qn /norestart DISABLE_TELEMETRY=1 /l*v `"$log`"" -Wait -PassThru
Write-Host "[INFO] msiexec exit=$($p.ExitCode)"
if ($p.ExitCode -notin @(0, 3010)) {
    Write-Host "[ERROR] 安装失败（exit=$($p.ExitCode)），日志: $log" -ForegroundColor Red
    exit 1
}

# ── 4.5 关闭遥测与更新检查（用户级环境变量，幂等）──
[Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'User')
[Environment]::SetEnvironmentVariable('POWERSHELL_UPDATECHECK', 'Off', 'User')
Write-Host "[OK] 已关闭遥测（POWERSHELL_TELEMETRY_OPTOUT=1）与更新检查（POWERSHELL_UPDATECHECK=Off）" -ForegroundColor Green

# ── 5. 验证（重新检测版本）──
Start-Sleep -Seconds 2
$verify = $null
foreach ($p in $probe) {
    if (Test-Path -LiteralPath $p) {
        $raw = (& $p -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null | Select-Object -First 1)
        if ($raw) { $verify = [version]($raw.ToString().Trim()); break }
    }
}
if ($verify -eq $target) {
    Write-Host "[OK] PowerShell 7 安装/升级完成: $verify" -ForegroundColor Green
    Write-Host "[HINT] 新开终端生效" -ForegroundColor DarkGray
    exit 0
}
Write-Host "[WARN] 验证版本 $verify 与目标 $target 不一致，请检查日志: $log" -ForegroundColor Yellow
exit 2
