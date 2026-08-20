#Requires -Version 5.1
# bootstrap.ps1 - 人类初始部署入口（原生 PowerShell 5.1 一键初始化）
# 用法: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\ohmypwsh\scripts\bootstrap.ps1
# 流程: 1) 装/升级 pwsh7  2) 部署 omp 模块  3) 注册 EnvRoot（幂等）

param(
    [string]$EnvRoot = '',
    [string]$PwshVersion = '7.6.5'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ── 0. EnvRoot 解析（参数 > OHMYENV_ROOT > D 盘 > C 盘）──
if (-not $EnvRoot) {
    if ($env:OHMYENV_ROOT -and $env:OHMYENV_ROOT.Trim()) {
        $EnvRoot = $env:OHMYENV_ROOT.Trim().TrimEnd('\')
    } elseif (Test-Path 'D:\') {
        $EnvRoot = 'D:\ohmyenv'
    } else {
        $EnvRoot = 'C:\ohmyenv'
    }
}
$EnvRoot = $EnvRoot.TrimEnd('\')
[Environment]::SetEnvironmentVariable('OHMYENV_ROOT', $EnvRoot, 'User')
$env:OHMYENV_ROOT = $EnvRoot

Write-Host "===== ohmypwsh 初始部署（EnvRoot=$EnvRoot）=====" -ForegroundColor Cyan

# ── 0.5 提前安装 aria2（PS5.1 兼容；后续 set-pwsh/ohmyenv 下载走 aria2 加速）──
function Install-EarlyAria2 {
    $lock = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot 'env.psd1')
    $a = $lock.Tools['aria2']
    if (-not $a -or -not $a.Asset) { Write-Host '[WARN] env.psd1 缺 aria2 pin，跳过提前安装' -ForegroundColor Yellow; return }
    $aria2Dir = Join-Path $EnvRoot 'aria2'
    $aria2Exe = Join-Path $aria2Dir 'aria2c.exe'
    if (Test-Path -LiteralPath $aria2Exe) {
        Write-Host "[OK] aria2 已就绪: $aria2Exe" -ForegroundColor Green
        $env:Path = "$aria2Dir;$env:Path"
        return
    }
    $url = "https://github.com/$($a.Repo)/releases/download/$($a.Tag)/$($a.Asset)"
    $zip = Join-Path $EnvRoot "cache\$($a.Asset)"
    New-Item -ItemType Directory -Path (Split-Path $zip) -Force | Out-Null
    if (-not (Test-Path -LiteralPath $zip)) {
        Write-Host "[INFO] 提前下载 aria2 ($($a.Version)) ..." -ForegroundColor Cyan
        $curl = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source
        if ($curl) {
            & $curl -L --fail --retry 5 --retry-delay 3 --connect-timeout 20 -sS -o $zip $url
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $zip)) { throw 'curl 下载 aria2 失败' }
        } else {
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 600
        }
    }
    $tmp = Join-Path $env:TEMP 'bootstrap-aria2'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
    $exe = Get-ChildItem $tmp -Recurse -Filter 'aria2c.exe' | Select-Object -First 1
    if (-not $exe) { throw 'aria2 zip 缺少 aria2c.exe' }
    New-Item -ItemType Directory -Path $aria2Dir -Force | Out-Null
    Copy-Item $exe.FullName $aria2Exe -Force
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $aria2Dir) {
        [Environment]::SetEnvironmentVariable('Path', "$aria2Dir;$userPath", 'User')
    }
    $env:Path = "$aria2Dir;$env:Path"
    Write-Host "[OK] aria2 提前就绪: $aria2Exe" -ForegroundColor Green
}
Install-EarlyAria2

# ── 1. 装/升级 pwsh7（复用 set-pwsh.ps1，含管理员提权）──
Write-Host '[1/3] 检测/安装 PowerShell 7 ...' -ForegroundColor Cyan
$setPwsh = Join-Path $PSScriptRoot 'set-pwsh.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setPwsh -Version $PwshVersion
if ($LASTEXITCODE -ne 0) { throw "set-pwsh.ps1 失败 (exit=$LASTEXITCODE)" }

# ── 2. 定位 pwsh7（set-pwsh.ps1 提权时是异步的，轮询等待）──
$pwsh  = $null
$probe = @(
    (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\PowerShell\7\pwsh.exe')
)
for ($i = 0; $i -lt 60 -and -not $pwsh; $i++) {
    foreach ($p in $probe) {
        if (Test-Path -LiteralPath $p) { $pwsh = $p; break }
    }
    if (-not $pwsh) { Start-Sleep -Seconds 2 }
}
if (-not $pwsh) { throw '未找到 pwsh.exe（set-pwsh.ps1 安装后应存在）' }

# ── 3. 部署 omp 模块（用 pwsh7 跑 deploy-omp.ps1）──
Write-Host '[2/3] 部署 omp 模块 ...' -ForegroundColor Cyan
$deployOmp = Join-Path $PSScriptRoot 'deploy-omp.ps1'
& $pwsh -NoProfile -ExecutionPolicy Bypass -File $deployOmp -EnvRoot $EnvRoot
if ($LASTEXITCODE -ne 0) { throw "deploy-omp.ps1 失败 (exit=$LASTEXITCODE)" }

# ── 4. 完成 ──
Write-Host '[3/3] 初始部署就绪' -ForegroundColor Cyan
Write-Host ''
Write-Host '[完成] 新开 pwsh 终端后可用：' -ForegroundColor Green
Write-Host '  omp status                 # 锁定 vs 已安装 vs PATH'
Write-Host '  omp deploy all             # 部署全部锁定工具'
Write-Host '  omp daily -DryRun          # 日常无影响更新预览'
