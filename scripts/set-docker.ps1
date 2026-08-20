#Requires -Version 7.0
# set-docker.ps1 - Windows 容器 Docker Engine 接管（官方 static 二进制 + 服务注册，幂等）
# 参考 raystyle/rxshell：docs/tools/docker.md + crates/rxs-core/src/docker_host.rs。
# 用法: pwsh -NoProfile -File scripts\set-docker.ps1 [-Version 29.7.1]
# 说明: 需管理员；会卸载旧的 rxshell docker 服务，注册到 D:\ohmyenv\docker\bin。

param([string]$Version = '29.7.1')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$envRoot    = Get-DefaultEnvRoot
$dockerDir  = Join-Path $envRoot 'docker'
$binDir     = Join-Path $dockerDir 'bin'
$dataRoot   = Join-Path $envRoot 'docker-data'
$cacheZip   = Join-Path $envRoot "cache\docker-$Version.zip"
$dlUrl      = "https://download.docker.com/win/static/stable/x86_64/docker-$Version.zip"
$daemonJson = 'C:\ProgramData\docker\config\daemon.json'
$group      = 'docker-users'
$service    = 'docker'
$logFile    = Join-Path $envRoot 'logs\docker-install.log'
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

function Write-Log([string]$m) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $m"
    Add-Content -LiteralPath $logFile -Value $line -Encoding utf8
    Write-Host $line
}

# ── 1. 提权 ──
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '[INFO] 需要管理员权限，正在提权重启本脚本...' -ForegroundColor Cyan
    $p = Start-Process (Get-Command pwsh).Source -Verb RunAs -Wait -PassThru -ArgumentList @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Version',$Version
    )
    if ($p.ExitCode -ne 0) {
        if (Test-Path -LiteralPath $logFile) { Get-Content -LiteralPath $logFile | ForEach-Object { Write-Host $_ } }
        throw "提权安装失败 exit=$($p.ExitCode)（详见 $logFile）"
    }
    if (Test-Path -LiteralPath $logFile) { Get-Content -LiteralPath $logFile | ForEach-Object { Write-Host $_ } }
    return
}

try {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null

    # ── 2. 下载官方 static zip 并解压 docker.exe / dockerd.exe ──
    if (-not (Test-Path -LiteralPath (Join-Path $binDir 'dockerd.exe'))) {
        if (-not (Test-Path -LiteralPath $cacheZip)) {
            Write-Log "[INFO] 下载 $dlUrl"
            Save-ReleaseAsset -Url $dlUrl -OutFile $cacheZip
        }
        $tmp = Join-Path $env:TEMP 'ohmyenv-docker-extract'
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        Expand-Archive -LiteralPath $cacheZip -DestinationPath $tmp -Force
        $dockerExe = Get-ChildItem $tmp -Recurse -Filter 'docker.exe' | Select-Object -First 1
        $dockerdExe = Get-ChildItem $tmp -Recurse -Filter 'dockerd.exe' | Select-Object -First 1
        if (-not $dockerExe -or -not $dockerdExe) { throw '官方 zip 缺少 docker.exe/dockerd.exe' }
        Copy-Item $dockerExe.FullName (Join-Path $binDir 'docker.exe') -Force
        Copy-Item $dockerdExe.FullName (Join-Path $binDir 'dockerd.exe') -Force
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Log "[OK] docker/dockerd 就绪: $binDir"

    # ── 3. docker-users 组 + 当前用户 ──
    $user = $env:USERNAME
    $null = net localgroup $group 2>$null
    if ($LASTEXITCODE -ne 0) { $null = net localgroup $group /add 2>&1 }
    $null = net localgroup $group $user /add 2>&1

    # ── 4. daemon.json（保留用户自定义键，仅确保 data-root 指向 EnvRoot 并补齐缺省键）──
    New-Item -ItemType Directory -Path (Split-Path $daemonJson) -Force | Out-Null
    $defaults = [ordered]@{
        'group'      = $group
        'log-driver' = 'json-file'
        'log-opts'   = [ordered]@{ 'max-size' = '10m'; 'max-file' = '3' }
        'exec-opts'  = @('isolation=process')
    }
    $existing = [ordered]@{}
    if (Test-Path -LiteralPath $daemonJson) {
        try { $existing = Get-Content -LiteralPath $daemonJson -Raw | ConvertFrom-Json -AsHashtable } catch {}
    }
    $changed = $false
    if ($existing['data-root'] -ne $dataRoot) { $existing['data-root'] = $dataRoot; $changed = $true }
    foreach ($k in $defaults.Keys) {
        if (-not $existing.ContainsKey($k)) { $existing[$k] = $defaults[$k]; $changed = $true }
    }
    if ($changed) {
        $json = $existing | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($daemonJson, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
        Write-Log "[OK] daemon.json 已更新: $daemonJson (data-root=$dataRoot)"
    } else {
        Write-Log '[INFO] daemon.json 已就绪（保留现有配置）'
    }

    # ── 4.5 检查 Windows 容器功能（未启用时告警，不自动重启）──
    $containersState = (dism.exe /Online /Get-FeatureInfo /FeatureName:Containers 2>&1 | Out-String)
    if ($containersState -notmatch 'Enabled|已启用|Enable Pending|启用 挂起') {
        Write-Log '[WARN] Windows 功能 Containers 未确认启用，服务可能无法启动'
    }

    # ── 5. 服务：仅当不存在或指向旧 rxshell 时才重注册 ──
    $dockerd = Join-Path $binDir 'dockerd.exe'
    $currentBin = (sc.exe qc $service 2>$null | Out-String)
    $serviceExists = ($currentBin -notmatch '1060|does not exist')
    $pointsToNew = ($currentBin -match [regex]::Escape($binDir))

    if ($serviceExists -and -not $pointsToNew) {
        Write-Log '[INFO] 检测到旧 rxshell docker 服务，卸载中...'
        $del = sc.exe delete $service 2>&1 | Out-String
        Write-Log "[INFO] sc delete docker: $del"
        Start-Sleep -Seconds 1
        $serviceExists = $false
    }

    if (-not $serviceExists) {
        $p = Start-Process -FilePath $dockerd -ArgumentList '--register-service' -Wait -PassThru -NoNewWindow
        Write-Log "[INFO] dockerd --register-service exit=$($p.ExitCode)"
        if ($p.ExitCode -ne 0) { throw "dockerd --register-service 失败 exit=$($p.ExitCode)" }
    }

    $null = sc.exe config $service start= auto
    $start = sc.exe start $service 2>&1 | Out-String
    Write-Log "[INFO] sc start docker: $start"
    Start-Sleep -Seconds 2
    $state = (sc.exe query $service 2>&1 | Out-String)
    Write-Log "[INFO] docker 服务状态:`n$state"
    if ($state -notmatch 'RUNNING') {
        Write-Log '[WARN] docker 服务未运行，可能刚启用 Windows 功能需重启'
    }

    # ── 6. PATH（机器级前置 docker bin）──
    $machine = [Environment]::GetEnvironmentVariable('Path','Machine')
    if ($machine -notlike "*$binDir*") {
        [Environment]::SetEnvironmentVariable('Path', "$binDir;$machine", 'Machine')
    }
    $env:Path = "$binDir;$env:Path"

    # ── 7. 校验 ──
    $ver = (& (Join-Path $binDir 'docker.exe') --version 2>&1 | Out-String).Trim()
    Write-Log "[OK] $ver"
    $info = (& (Join-Path $binDir 'docker.exe') info 2>&1 | Out-String)
    Write-Log "[INFO] docker info:`n$info"
    if ($info -notmatch 'windowsfilter' -and $info -notmatch 'OSType: windows') {
        Write-Log '[WARN] docker info 未确认 Windows 容器引擎，请检查服务状态'
    }
    Write-Log '[完成] Docker Engine 接管就绪。'
}
catch {
    Write-Log "[ERROR] $($_.Exception.Message)"
    throw
}
