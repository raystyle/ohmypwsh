#Requires -Version 7.0
# set-python-config.ps1 - 为 ohmyenv 托管的 Python 建立 python3 命令别名（与 Linux 对齐，幂等）
# 用法: pwsh -NoProfile -File scripts\set-python-config.ps1
# 说明: python-build-standalone 的 Windows 发行版只带 python.exe/pythonw.exe，没有 python3；
#       本脚本在 EnvRoot\python 复制 python.exe -> python3.exe（复用同目录 python3.dll），
#       使 python3 与 Linux 命令一致。
# 注意: python 版本升级（ohmyenv update python）会重解压目录，需重跑本脚本恢复别名。

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')   # 重建 PATH（注册表权威）

$envRoot    = Get-DefaultEnvRoot
$pythonDir  = Join-Path $envRoot 'python'
$pythonExe  = Join-Path $pythonDir 'python.exe'
$python3Exe = Join-Path $pythonDir 'python3.exe'

if (-not (Test-Path -LiteralPath $pythonExe)) {
    throw "未找到 python: $pythonExe（先 ohmyenv deploy python）"
}

if (Test-Path -LiteralPath $python3Exe) {
    $v = & $python3Exe --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[INFO] python3 别名已存在: $python3Exe（$v）" -ForegroundColor DarkGray
        return
    }
    Remove-Item -LiteralPath $python3Exe -Force
}

Copy-Item -LiteralPath $pythonExe -Destination $python3Exe -Force
$v = & $python3Exe --version 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "python3 别名创建后校验失败: $v"
}
Write-Host "[OK] python3 别名已建立: $python3Exe -> python.exe（$v）" -ForegroundColor Green
