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
