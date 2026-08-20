#Requires -Version 7.0
# set-node-config.ps1 - Node.js/nvm 配置（NVM_HOME/NVM_SYMLINK/镜像/npm registry，幂等）
# 用法: pwsh -NoProfile -File scripts\set-node-config.ps1

$ErrorActionPreference = 'Stop'

$nvmHome    = 'D:\ohmyenv\nvm'
$nvmSymlink = 'D:\ohmyenv\nodejs'
$nodeMirror = 'https://npmmirror.com/mirrors/node/'
$npmMirror  = 'https://npmmirror.com/mirrors/npm/'
$registry   = 'https://registry.npmmirror.com'

# ── 1. 用户环境变量：NVM_HOME / NVM_SYMLINK ──
foreach ($pair in @(@('NVM_HOME', $nvmHome), @('NVM_SYMLINK', $nvmSymlink))) {
    $name = $pair[0]; $val = $pair[1]
    if ([Environment]::GetEnvironmentVariable($name, 'User') -ne $val) {
        [Environment]::SetEnvironmentVariable($name, $val, 'User')
        Set-Item "Env:$name" $val
        Write-Host "[OK] $name = $val" -ForegroundColor Green
    } else {
        Write-Host "[INFO] $name 已设置" -ForegroundColor DarkGray
    }
}

# ── 2. 用户 PATH 前置 NVM_SYMLINK（node/npm 命令入口）──
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = $userPath -split ';' | Where-Object { $_ }
if ($parts -notcontains $nvmSymlink) {
    [Environment]::SetEnvironmentVariable('Path', (@($nvmSymlink) + $parts) -join ';', 'User')
    Write-Host "[OK] PATH 已前置 $nvmSymlink" -ForegroundColor Green
} else {
    Write-Host '[INFO] NVM_SYMLINK 已在 PATH' -ForegroundColor DarkGray
}
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# ── 3. nvm settings.txt：root/path/镜像（幂等）──
$settingsPath = Join-Path $nvmHome 'settings.txt'
$settings = [ordered]@{
    root        = $nvmHome
    path        = $nvmSymlink
    node_mirror = $nodeMirror
    npm_mirror  = $npmMirror
}
$lines = New-Object System.Collections.Generic.List[string]
foreach ($k in $settings.Keys) {
    $lines.Add("$k`: $($settings[$k])")
}
$newText = ($lines -join "`r`n") + "`r`n"
$oldText = if (Test-Path -LiteralPath $settingsPath) { [System.IO.File]::ReadAllText($settingsPath) } else { '' }
if ($oldText.Trim() -ne $newText.Trim()) {
    [System.IO.File]::WriteAllText($settingsPath, $newText, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "[OK] settings.txt 已写入（root/path/node_mirror/npm_mirror）" -ForegroundColor Green
} else {
    Write-Host '[INFO] settings.txt 已是最新' -ForegroundColor DarkGray
}

# ── 4. npm registry（node/npm 安装后生效；此处幂等写用户 .npmrc）──
$npmrc = Join-Path $env:USERPROFILE '.npmrc'
$regLine = "registry=$registry"
$needWrite = $false
if (Test-Path -LiteralPath $npmrc) {
    $cur = [System.IO.File]::ReadAllText($npmrc)
    if ($cur -notmatch '(?m)^registry\s*=') { $needWrite = $true }
    elseif ($cur -notmatch [regex]::Escape($registry)) { $needWrite = $true }
} else {
    $needWrite = $true
}
if ($needWrite) {
    $out = if (Test-Path -LiteralPath $npmrc) {
        ([System.IO.File]::ReadAllLines($npmrc) | Where-Object { $_ -notmatch '^registry\s*=' }) -join "`r`n"
    } else { '' }
    $out = ($out.TrimEnd() + "`r`n$regLine`r`n")
    [System.IO.File]::WriteAllText($npmrc, $out, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "[OK] npm registry 已配置: $registry" -ForegroundColor Green
} else {
    Write-Host '[INFO] npm registry 已配置' -ForegroundColor DarkGray
}

Write-Host '[完成] nvm 配置就绪。安装并切换 node: nvm install lts && nvm use lts（需管理员）' -ForegroundColor Cyan
