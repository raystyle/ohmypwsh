#Requires -Version 7.0
# deploy-omp.ps1 - 部署 omp 模块到 EnvRoot\modules\omp（幂等）
# 用法: pwsh -NoProfile -File scripts\deploy-omp.ps1 [-EnvRoot <路径>]
# 说明: 把 omp.psm1 / omp.psd1 / helpers.ps1 / env.psd1 打包到模块目录，并注册 PSModulePath。

param([string]$EnvRoot = '')

$ErrorActionPreference = 'Stop'

if ($EnvRoot) { $env:OHMYENV_ROOT = $EnvRoot.Trim().TrimEnd('\') }
. (Join-Path $PSScriptRoot 'helpers.ps1')   # 重建 PATH + Get-DefaultEnvRoot

$envRoot    = Get-DefaultEnvRoot
$moduleRoot = Join-Path $envRoot 'modules'
$moduleDir  = Join-Path $moduleRoot 'omp'

# ── 1. 拷贝模块文件（omp.psm1 / omp.psd1 / helpers.ps1 / env.psd1）──
New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
foreach ($f in @('omp.psm1', 'omp.psd1', 'helpers.ps1', 'env.psd1')) {
    $src = Join-Path $PSScriptRoot $f
    if (-not (Test-Path -LiteralPath $src)) { throw "缺少模块文件: $src" }
    $dst = Join-Path $moduleDir $f
    $needCopy = $true
    if (Test-Path -LiteralPath $dst) {
        if ((Get-FileHash -LiteralPath $src).Hash -eq (Get-FileHash -LiteralPath $dst).Hash) { $needCopy = $false }
    }
    if ($needCopy) {
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Host "[OK] 已部署: $f" -ForegroundColor Green
    } else {
        Write-Host "[INFO] 已一致: $f" -ForegroundColor DarkGray
    }
}

# ── 2. 注册 PSModulePath（EnvRoot\modules）──
$psmp  = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
$parts = @($psmp -split ';' | Where-Object { $_ })
if ($parts -notcontains $moduleRoot) {
    [Environment]::SetEnvironmentVariable('PSModulePath', (@($moduleRoot) + $parts) -join ';', 'User')
    $env:PSModulePath = "$moduleRoot;$env:PSModulePath"
    Write-Host "[OK] PSModulePath 已注册: $moduleRoot" -ForegroundColor Green
} else {
    Write-Host "[INFO] PSModulePath 已存在: $moduleRoot" -ForegroundColor DarkGray
}

# ── 3. 验证清单可读 ──
$manifest = Import-PowerShellDataFile -Path (Join-Path $moduleDir 'omp.psd1')
Write-Host "[OK] omp 模块已部署: $moduleDir (v$($manifest.ModuleVersion))" -ForegroundColor Green
