#Requires -Version 7.0
# build-wsl-image.ps1 - 构建 ohmywsl WSL 初始镜像（.wsl），模板落到 EnvRoot\images\wsl
# 参考 D:\ohmywsl2\scripts\build.ps1；组件脚本复用 -ComponentDir（默认 D:\ohmywsl2\scripts）。
# 用法: pwsh -NoProfile -File scripts\build-wsl-image.ps1 [-Version 0.1.0] [-Variant dev|native] [-Force]

param(
    [string]$Version = '',
    [ValidateSet('dev', 'native')]
    [string]$Variant = 'dev',
    [switch]$Force,
    [string]$ComponentDir = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')

if (-not $ComponentDir) { $ComponentDir = Join-Path $PSScriptRoot 'wsl' }

$envRoot    = Get-DefaultEnvRoot
$ImagesDir  = Join-Path $envRoot 'images\wsl'
$CacheDir   = Join-Path $envRoot 'cache\wsl'
$WslFileName = 'ubuntu-24.04.4-wsl-amd64.wsl'
$WslUrl     = "https://releases.ubuntu.com/noble/$WslFileName"
$WslSha256  = '9b2f7730dc68227dd04a9f3e5eab86ad85caf556b8606ad94f1f29ff5c4fd3f5'
$DistroName = 'ohmyenv-wsl-build'
$LinuxUser  = 'ray'
$LinuxPass  = 'ubuntu'
$Arch       = 'amd64'
$VariantSuffix = if ($Variant -eq 'native') { '-native' } else { '' }

if (-not $Version) { $Version = '0.1.0' }
$OriginalWsl = Join-Path $CacheDir $WslFileName
$ImageFile   = Join-Path $ImagesDir "ohmywsl-$Version$VariantSuffix-wsl-$Arch.wsl"
$TarFile     = Join-Path $ImagesDir "rootfs-$Version$VariantSuffix.tar"
$ReportFile  = Join-Path $ImagesDir "ohmywsl-$Version$VariantSuffix-wsl-$Arch.report.json"

New-Item -ItemType Directory -Path $ImagesDir -Force | Out-Null
New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null

function ConvertTo-WslPath([string]$WinPath) {
    $drive = $WinPath.Substring(0, 1).ToLower()
    return "/mnt/$drive" + $WinPath.Substring(2).Replace('\', '/')
}

function Invoke-Wsl {
    param([string]$ScriptPath, [string]$Action = 'install', [string]$VersionArg = '', [string]$User = $LinuxUser)
    $wslPath = ConvertTo-WslPath "$ComponentDir\$ScriptPath"
    $cmd = "bash '$wslPath' '$Action'"
    if ($VersionArg) { $cmd += " '$VersionArg'" }
    wsl --cd (ConvertTo-WslPath $ComponentDir) -d $DistroName -u $User -e bash -lc $cmd
    if ($LASTEXITCODE -ne 0) { throw "$ScriptPath $Action 失败 (exit=$LASTEXITCODE)" }
    Write-Host "[OK] $ScriptPath $Action 完成" -ForegroundColor Green
}

function Test-WslDistro([string]$Name) {
    $prev = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    $list = wsl -l -q 2>$null | Where-Object { $_.Trim() -eq $Name }
    [Console]::OutputEncoding = $prev
    return [bool]$list
}

try {
    Write-Host "===== 构建 ohmywsl 镜像（版本=$Version 变体=$Variant）=====" -ForegroundColor Cyan

    # 1. 官方 Ubuntu 镜像（下载到 EnvRoot 缓存）
    $needDownload = $true
    if (Test-Path -LiteralPath $OriginalWsl) {
        $h = (Get-FileHash $OriginalWsl -Algorithm SHA256).Hash.ToLower()
        if ($h -eq $WslSha256) { Write-Host '[OK] 官方镜像已就绪并校验通过'; $needDownload = $false }
        else { Write-Host '[WARN] 官方镜像 SHA 不匹配，重新下载' }
    }
    if ($needDownload) {
        Write-Host "[INFO] 下载 $WslUrl ..."
        # releases.ubuntu.com 对 aria2 的 TLS 握手偶发失败/降速，curl.exe(schannel) 更稳；失败再回退 aria2
        $curl = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source
        if ($curl) {
            & $curl -L --fail --retry 5 --retry-delay 3 --connect-timeout 20 -sS -o $OriginalWsl $WslUrl
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OriginalWsl)) {
                Write-Host '[WARN] curl 下载失败，改用 aria2' -ForegroundColor Yellow
                Save-ReleaseAsset -Url $WslUrl -OutFile $OriginalWsl
            }
        } else {
            Save-ReleaseAsset -Url $WslUrl -OutFile $OriginalWsl
        }
        if ((Get-FileHash $OriginalWsl -Algorithm SHA256).Hash.ToLower() -ne $WslSha256) { throw '官方镜像 SHA256 校验失败' }
    }

    # 2. 清理旧构建 distro
    if (Test-WslDistro $DistroName) {
        if (-not $Force) { throw "已存在 $DistroName，使用 -Force 重建" }
        wsl --shutdown | Out-Null
        wsl --unregister $DistroName 2>$null | Out-Null
    }

    # 3. 导入构建 distro
    Write-Host "[INFO] 导入构建 distro $DistroName ..."
    wsl --import $DistroName $CacheDir $OriginalWsl --version 2 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "WSL 导入失败 exit=$LASTEXITCODE" }
    wsl --manage $DistroName --set-sparse true --allow-unsafe 2>$null | Out-Null

    # 4. base-config（root）
    $baseScript = ConvertTo-WslPath "$ComponentDir\base\base-config.sh"
    wsl -d $DistroName -u root --exec bash "$baseScript" "$LinuxUser" "$LinuxPass"
    if ($LASTEXITCODE -ne 0) { throw 'base-config 失败' }

    # 5. base 组件
    Invoke-Wsl 'base/apt-sources.sh' install
    Invoke-Wsl 'base/git.sh' install

    # 6. dev 组件
    if ($Variant -eq 'native') {
        Write-Host '[WARN] native 变体跳过 dev 工具链'
    } else {
        foreach ($s in 'dev/node.sh','dev/bun.sh','dev/rust.sh','dev/uv.sh','dev/go.sh','dev/zig.sh') {
            Invoke-Wsl $s install
        }
    }

    # 7. 工具版本
    $toolVersions = @{}
    if ($Variant -ne 'native') {
        $probeSh = ConvertTo-WslPath "$ComponentDir\tool-versions.sh"
        $out = wsl --cd (ConvertTo-WslPath $ComponentDir) -d $DistroName -u $LinuxUser -e bash -lc "bash '$probeSh'" 2>&1
        foreach ($line in $out) {
            if ($line -match '^([a-zA-Z0-9+_-]+):\s*(.*)$') { $toolVersions[$Matches[1]] = $Matches[2] }
        }
    }

    # 8. 清理 + 导出 + gzip
    Invoke-Wsl 'clean.sh' run
    wsl --terminate $DistroName | Out-Null
    Start-Sleep -Seconds 3
    if (Test-Path $TarFile) { [System.IO.File]::Delete($TarFile) }
    wsl --export $DistroName $TarFile | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "wsl --export 失败 exit=$LASTEXITCODE" }
    if (Test-Path $ImageFile) { [System.IO.File]::Delete($ImageFile) }
    $in = [System.IO.File]::OpenRead($TarFile)
    $out = [System.IO.File]::Create($ImageFile)
    $gzip = New-Object System.IO.Compression.GZipStream($out, [System.IO.Compression.CompressionLevel]::Optimal)
    $in.CopyTo($gzip)
    $gzip.Dispose(); $out.Dispose(); $in.Dispose()
    [System.IO.File]::Delete($TarFile)

    # 9. 报告
    $sha = (Get-FileHash $ImageFile -Algorithm SHA256).Hash.ToLower()
    [ordered]@{
        name = 'ohmywsl'; version = $Version; variant = $Variant
        buildTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        distro = 'Ubuntu 24.04.4 (noble)'
        imageSizeMB = [math]::Round((Get-Item $ImageFile).Length / 1MB, 1)
        sha256 = $sha
        tools = $toolVersions
    } | ConvertTo-Json -Depth 4 | Set-Content $ReportFile -Encoding UTF8

    # 10. 注销构建 distro
    wsl --unregister $DistroName 2>$null | Out-Null

    Write-Host "[完成] 镜像模板: $ImageFile" -ForegroundColor Green
    Write-Host "[完成] 报告: $ReportFile" -ForegroundColor Green
}
finally {
    if (Test-WslDistro $DistroName) { wsl --unregister $DistroName 2>$null | Out-Null }
}
