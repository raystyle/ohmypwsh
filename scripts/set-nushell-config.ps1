#Requires -Version 7.0
# set-nushell-config.ps1 - 官方 nushell 插件注册（幂等）
# 参考 omc 的 nushell.ps1 PostInstall：对 bin 目录中的 nu_plugin_*.exe 逐个 `plugin add`。
# 差异：官方 nushell 的字符串字面量把反斜杠当转义，插件路径必须用正斜杠。
# 用法: pwsh -NoProfile -File scripts\set-nushell-config.ps1
# 前置: 先 `ohmyenv.ps1 deploy nushell`（nu.exe + 插件 + PATH）

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')   # 重建 PATH（注册表权威）+ Get-DefaultEnvRoot

$envRoot   = Get-DefaultEnvRoot
$nuDir     = Join-Path $envRoot 'nushell'
$nuExe     = Join-Path $nuDir 'nu.exe'

if (-not (Test-Path -LiteralPath $nuExe)) {
    throw "未找到 nu.exe: $nuExe`n请先运行: pwsh -NoProfile -File scripts\ohmyenv.ps1 deploy nushell"
}

# 官方 zip 会附带 nu_plugin_stress_internals.exe（压测插件），不注册
$plugins = Get-ChildItem -LiteralPath $nuDir -Filter 'nu_plugin_*.exe' -File |
    Where-Object { $_.Name -ne 'nu_plugin_stress_internals.exe' } |
    Sort-Object Name

if (-not $plugins) {
    Write-Host '[INFO] 未找到 nushell 插件，跳过注册' -ForegroundColor DarkGray
    return
}

foreach ($p in $plugins) {
    # nu 字符串字面量会把 \o/\n 等当转义；转成正斜杠即可
    $pluginPath = $p.FullName.Replace('\', '/')
    $null = & $nuExe -c "plugin add `"$pluginPath`"" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "插件注册失败: $($p.Name)"
    }
    Write-Host "[OK] 已注册插件: $($p.Name)" -ForegroundColor Green
}

Write-Host '[完成] nushell 插件已注册到用户插件注册表（%APPDATA%\nushell\plugin.msgpackz）。' -ForegroundColor Cyan
