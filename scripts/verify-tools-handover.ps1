#Requires -Version 7.0
# verify-tools-handover.ps1 - 扩展工具交接验证（rg/jq/yq/rmux/starship，新终端一键 PASS/FAIL）
# 用法：pwsh -NoProfile -File D:\ohmypwsh\scripts\verify-tools-handover.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')   # 重建 PATH（注册表权威）+ 锁定清单/版本解析

$lock  = Get-EnvLock
$tools = @('rg', 'jq', 'yq', 'rmux', 'starship')
$fail  = 0

foreach ($t in $tools) {
    $d        = $lock.Tools[$t]
    $expected = Join-Path $lock.EnvRoot $d.Exe
    $cmd      = Get-Command $t -ErrorAction SilentlyContinue | Select-Object -First 1
    $ver      = Get-InstalledVersion -ExePath $expected -Tool $t

    Write-Host "=== $t ===" -ForegroundColor Cyan
    Write-Host "source  : $(if ($cmd) { $cmd.Source } else { '(未找到)' })"
    Write-Host "version : $(if ($ver) { $ver } else { '(无法读取)' })（locked=$($d.Version)）"

    if (-not $cmd -or $cmd.Source -ne $expected -or $ver -ne $d.Version) {
        Write-Host "[X] FAIL: $t 未解析到 $expected，或版本与锁定不符" -ForegroundColor Red
        $fail++
    } else {
        Write-Host "[OK] PASS: $t -> $expected ($ver)" -ForegroundColor Green
    }
}

if ($fail -gt 0) {
    Write-Host "[X] 交接验证失败（$fail 项）；请开全新终端重试，或检查 PATH 顺序" -ForegroundColor Red
    exit 1
}

# starship 配置完整性（接管保留项：~/.config/starship.toml 为 starship 默认配置路径）
$starshipConfig = Join-Path $env:USERPROFILE '.config\starship.toml'
if (-not (Test-Path $starshipConfig)) {
    Write-Host "[X] FAIL: starship 配置文件缺失: $starshipConfig" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] starship 配置就位: $starshipConfig" -ForegroundColor Green

Write-Host '[OK] 全部 PASS：rg / jq / yq / rmux / starship 均由 ohmyenv 接管' -ForegroundColor Green
exit 0
