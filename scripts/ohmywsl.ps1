#Requires -Version 7.0
# ohmywsl.ps1 - WSL（Linux）软件部署 CLI（工具清单见 scripts\wsl-env.psd1）
# 语义与 ohmyenv.ps1 对齐：query / pin / install / update / status；Windows 编排下载/校验，
# 部署包统一缓存在 EnvRoot\cache\wsl-tools\<tool>\，Linux 侧经 scripts\wsl\tools\<tool>.sh
# 组件脚本解包 / cp 绿色二进制到 WSL ~/.local/bin（PATH 由基础镜像 .bashrc.d/local-bin.sh 保证）。
# 用法: pwsh -NoProfile -File scripts\ohmywsl.ps1 <command> [tool|all] [options]

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('query', 'pin', 'install', 'update', 'status', 'help')]
    [string]$Command = 'help',

    [Parameter(Position = 1)]
    [string]$Tool = 'all',

    [switch]$Latest,
    [string]$Tag,
    [string]$Version,
    [string]$Distro,
    [string]$User,
    [switch]$Force,
    [string]$EnvRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$script:WslLockPath = Join-Path $PSScriptRoot 'wsl-env.psd1'
$script:WslComponentDir = Join-Path $PSScriptRoot 'wsl\tools'

function ConvertTo-WslPath {
    param([Parameter(Mandatory)][string]$WinPath)
    $drive = $WinPath.Substring(0, 1).ToLower()
    return '/mnt/' + $drive + $WinPath.Substring(2).Replace('\', '/')
}

function Invoke-Wsl {
    <#
    .SYNOPSIS
        在目标 distro 内以指定用户执行 bash 命令；统一处理 wsl 输出 UTF-16LE 与控制台编码。
    #>
    param(
        [Parameter(Mandatory)][string]$DistroName,
        [Parameter(Mandatory)][string]$UserArg,
        [Parameter(Mandatory)][string]$Command,
        [switch]$Root
    )
    $prev = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    try {
        $u = if ($Root) { 'root' } else { $UserArg }
        # wsl -e bash -lc 保持命令字面，避免通过默认 shell 的引号二次解析
        & wsl -d $DistroName -u $u -e bash -lc $Command
        return $LASTEXITCODE
    } finally {
        [Console]::OutputEncoding = $prev
    }
}

function Test-WslDistro {
    param([Parameter(Mandatory)][string]$Name)
    $prev = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    try {
        $list = wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $Name }
        return [bool]$list
    } finally {
        [Console]::OutputEncoding = $prev
    }
}

function Get-WslLock {
    param([string]$EnvRootOverride)
    if (Test-Path $script:WslLockPath) {
        $lock = Import-PowerShellDataFile -Path $script:WslLockPath
    } else {
        $lock = @{ Distro = 'ohmywsl'; User = 'ray'; Tools = @{} }
    }
    # EnvRoot 复用 Windows 侧解析（下载缓存 / .secrets 等都以 EnvRoot 为准）
    $lock['EnvRoot'] = if ($EnvRootOverride -and $EnvRootOverride.Trim()) {
        $EnvRootOverride.Trim().TrimEnd('\')
    } else {
        Get-DefaultEnvRoot
    }
    if (-not $lock.Distro) { $lock['Distro'] = 'ohmywsl' }
    if (-not $lock.User)   { $lock['User']   = 'ray' }
    $lock
}

function Save-WslLock {
    param([Parameter(Mandatory)][hashtable]$Lock)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# wsl-env.psd1 - WSL（Linux）软件部署锁定清单（由 ohmywsl.ps1 维护，勿手改）')
    $lines.Add('# 与 env.psd1 同构：字段语义与 Windows 侧一致，但资产为 Linux 资产；唯一 pin 来源。')
    $lines.Add('# 注意：含中文须 UTF-8 带 BOM（AGENTS 规则 4）。')
    $lines.Add('@{')
    $lines.Add("    Distro = '$($Lock.Distro)'")
    $lines.Add("    User   = '$($Lock.User)'")
    $lines.Add('    Tools  = @{')
    foreach ($t in @($Lock.Tools.Keys | Sort-Object)) {
        $d = $Lock.Tools[$t]
        $lines.Add("        '$t' = @{")
        $lines.Add("            Version      = '$($d.Version)'")
        $lines.Add("            Tag          = '$($d.Tag)'")
        $lines.Add("            TagPrefix    = '$($d.TagPrefix)'")
        $lines.Add("            Repo         = '$($d.Repo)'")
        $lines.Add("            AssetPattern = '$($d.AssetPattern)'")
        $lines.Add("            Asset        = '$($d.Asset)'")
        $lines.Add("            SumsAsset    = '$($d.SumsAsset)'")
        $lines.Add("            SumsPattern  = '$($d.SumsPattern)'")
        $lines.Add("            Component    = '$($d.Component)'")
        if ($d.CdnIndexUrl)     { $lines.Add("            CdnIndexUrl      = '$($d.CdnIndexUrl)'") }
        if ($d.CdnAssetPattern) { $lines.Add("            CdnAssetPattern  = '$($d.CdnAssetPattern)'") }
        if ($d.AssetShaSuffix) { $lines.Add("            AssetShaSuffix = '$($d.AssetShaSuffix)'") }
        $lines.Add("            Sha256       = '$($d.Sha256)'")
        $lines.Add('        }')
    }
    $lines.Add('    }')
    $lines.Add('}')
    $lines | Set-Content -Path $script:WslLockPath -Encoding utf8BOM
    Write-Host "[OK] 锁定清单已写入: $script:WslLockPath" -ForegroundColor Green
}

function Get-WslTools {
    param([Parameter(Mandatory)][hashtable]$Lock, [string]$ToolArg)
    $all = @($Lock.Tools.Keys)
    if ($ToolArg -eq 'all') {
        return @($all | Sort-Object)
    }
    if ($all -notcontains $ToolArg) {
        throw "未知 WSL 工具: $ToolArg（清单内: $($all -join ' / ')）"
    }
    return @($ToolArg)
}

function Resolve-WslTool {
    <#
    .SYNOPSIS
        解析 WSL 工具目标版本与资产（复用 helpers.ps1 的 Get-GitHubRelease / Find-ReleaseAsset，
        但用 wsl-env.psd1 工具定义；Linux 资产无 Extract/Cdn 特殊来源，先聚焦 GitHub release）。
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)][string]$ToolName,
        [switch]$Latest,
        [string]$Tag,
        [string]$Version
    )
    $d = $Lock.Tools[$ToolName]
    if ($d.CdnIndexUrl) {
        # HashiCorp CDN 来源（复用 helpers.ps1 的 Get-HashiCorpIndex）
        $ver = if ($Version) { $Version } elseif ($Latest) { '' } elseif ($d.Version) { $d.Version } else { throw "$ToolName 需 -Version 或先 pin（HashiCorp 来源）" }
        $info = if ($Latest) {
            Get-HashiCorpIndex -IndexUrl $d.CdnIndexUrl -Latest
        } else {
            Get-HashiCorpIndex -IndexUrl $d.CdnIndexUrl -Version $ver
        }
        $ver = $info.version
        $pattern = $d.CdnAssetPattern.Replace('{version}', [regex]::Escape($ver))
        $build = $info.builds | Where-Object { $_.filename -match $pattern } | Select-Object -First 1
        if (-not $build) { throw "$ToolName $ver 在 index.json 中未找到匹配构建: $($d.CdnAssetPattern)" }
        return @{
            Tool       = $ToolName
            Tag        = $ver
            Version    = $ver
            AssetName  = $build.filename
            AssetSize  = 0
            AssetUrl   = $build.url
            Release    = $null
            Shasums    = $info.shasums
            ShasumsUrl = $build.url.Replace($build.filename, $info.shasums)
        }
    }
    if ($Latest) {
        $release = Get-GitHubRelease -Repo $d.Repo -Latest
    } elseif ($Tag) {
        $release = Get-GitHubRelease -Repo $d.Repo -Tag $Tag
    } elseif ($Version) {
        $prefix = if ($null -ne $d.TagPrefix) { $d.TagPrefix } else { 'v' }
        $release = Get-GitHubRelease -Repo $d.Repo -Tag "$prefix$Version"
    } else {
        if (-not $d.Tag) { throw "$ToolName 尚未 pin 版本。先执行: ohmywsl.ps1 pin $ToolName -Latest" }
        $release = Get-GitHubRelease -Repo $d.Repo -Tag $d.Tag
    }
    $asset = Find-ReleaseAsset -Release $release -Pattern $d.AssetPattern
    $prefix = if ($null -ne $d.TagPrefix) { $d.TagPrefix } else { 'v' }
    $ver = $release.tag_name
    if ($ver.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $ver = $ver.Substring($prefix.Length)
    }
    @{
        Tool      = $ToolName
        Tag       = $release.tag_name
        Version   = $ver
        AssetName = $asset.name
        AssetSize = $asset.size
        AssetUrl  = $asset.browser_download_url
        Release   = $release
    }
}

function Set-WslPin {
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)]$Resolution
    )
    $d = $Lock.Tools[$Resolution.Tool]
    $d.Tag     = $Resolution.Tag
    $d.Version = $Resolution.Version
    $d.Asset   = $Resolution.AssetName
    $d.Sha256  = ''
    Save-WslLock -Lock $Lock
    Write-Host "[OK] $($Resolution.Tool) 已 pin: $($Resolution.Version)（sha256 将在 install 时回填）" -ForegroundColor Green
}

function Get-WslInstalledVersion {
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)][string]$ToolName,
        [string]$DistroName,
        [string]$UserArg
    )
    $component = $Lock.Tools[$ToolName].Component
    $scriptPath = ConvertTo-WslPath (Join-Path $script:WslComponentDir "$component.sh")
    $out = & wsl --cd (ConvertTo-WslPath $script:WslComponentDir) -d $DistroName -u $UserArg -e bash -lc "bash '$scriptPath' version 2>&1" 2>$null
    return (($out -join ' ').Trim())
}

function Install-WslTool {
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)]$Resolution,
        [string]$DistroName,
        [string]$UserArg,
        [switch]$UpdateLock,
        [switch]$Force
    )
    $t  = $Resolution.Tool
    $d  = $Lock.Tools[$t]
    $envRoot = $Lock.EnvRoot
    $cacheDir  = Join-Path $envRoot "cache\wsl-tools\$t"
    $cachePath = Join-Path $cacheDir $Resolution.AssetName
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null

    Write-Host "===== $t ($($Resolution.Tag)) =====" -ForegroundColor Cyan

    # 官方校验源优先（统一 checksums），缺失回退锁定 sha（同 tag 缓存复用）
    $expectedSha = Get-OfficialSha256 -Lock $Lock -Resolution $Resolution
    if (-not $expectedSha -and $d.Sha256 -and $Resolution.Tag -eq $d.Tag) {
        $expectedSha = $d.Sha256
    }
    $forceDownload = ($Resolution.Tag -ne $d.Tag) -or $Force
    Save-ReleaseAsset -Url $Resolution.AssetUrl -OutFile $cachePath -ExpectedSha256 $expectedSha -Force:$forceDownload

    $sha = (Get-FileHash -LiteralPath $cachePath -Algorithm SHA256).Hash
    if ($Resolution.Tag -eq $d.Tag) {
        if ($d.Sha256 -and $sha -ne $d.Sha256) { throw "$t 缓存 sha256 与锁定不符" }
        if (-not $d.Sha256) { $d.Sha256 = $sha; Save-WslLock -Lock $Lock; Write-Host "[OK] 已回填 sha256" -ForegroundColor Green }
    } else {
        $d.Sha256 = $sha
    }

    $component = $d.Component
    $scriptPath = ConvertTo-WslPath (Join-Path $script:WslComponentDir "$component.sh")
    $assetPath  = ConvertTo-WslPath $cachePath
    Invoke-Wsl -DistroName $DistroName -UserArg $UserArg -Command "bash '$scriptPath' install '$($Resolution.Version)' '$assetPath'" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "$t 组件脚本 install 失败 (exit=$LASTEXITCODE)" }

    if ($UpdateLock) {
        $d.Tag     = $Resolution.Tag
        $d.Version = $Resolution.Version
        $d.Asset   = $Resolution.AssetName
        Save-WslLock -Lock $Lock
        Write-Host "[OK] $t 已锁定: $($d.Version)" -ForegroundColor Green
    }
    $installed = Get-WslInstalledVersion -Lock $Lock -ToolName $t -DistroName $DistroName -UserArg $UserArg
    Write-Host "[OK] $t 安装完成，WSL 内版本: $installed" -ForegroundColor Green
}

function Show-WslHelp {
    @'
ohmywsl - WSL（Linux）软件部署 CLI

用法:
  ohmywsl.ps1 query   [tool|all] [-Latest | -Tag <tag> | -Version <ver>]
  ohmywsl.ps1 pin     [tool|all] [-Latest | -Version <ver>]   # pin 写入 scripts\wsl-env.psd1
  ohmywsl.ps1 install [tool|all] [-Distro ohmywsl] [-User ray] [-Force]
  ohmywsl.ps1 update  [tool|all] [-Distro ohmywsl] [-User ray] # 更新到最新并重新 pin
  ohmywsl.ps1 status                                          # distro + pin vs installed
  ohmywsl.ps1 help

说明:
  - Windows 侧下载 + 官方哈希校验（部署包统一缓存 EnvRoot\cache\wsl-tools\<tool>\），
    Linux 侧经 scripts\wsl\tools\<tool>.sh 组件脚本解包 / cp 绿色二进制进 WSL
  - pin 唯一来源 scripts\wsl-env.psd1
  - distro 默认 ohmywsl（-Distro 覆盖）；WSL 内二进制安装到 $HOME/.local/bin（PATH 已由基础镜像保证）
'@
}

$lock    = Get-WslLock -EnvRootOverride $EnvRoot
$distro  = if ($Distro -and $Distro.Trim()) { $Distro.Trim() } else { $lock.Distro }
$user    = if ($User -and $User.Trim()) { $User.Trim() } else { $lock.User }

# 需要 distro 的命令先探测，缺失给引导（query / pin / help 不依赖 distro）
$needDistro = $Command -in @('install', 'update', 'status')
if ($needDistro -and -not (Test-WslDistro -Name $distro)) {
    Write-Host "[WARN] WSL distro '$distro' 不存在。" -ForegroundColor Yellow
    Write-Host "       先装/更新 WSL:  pwsh -NoProfile -File scripts\set-wsl.ps1"
    Write-Host "       再导入基础镜像: pwsh -NoProfile -File scripts\set-wsl-distro.ps1"
    exit 3
}

switch ($Command) {
    'query' {
        foreach ($t in (Get-WslTools -Lock $lock -ToolArg $Tool)) {
            $r = Resolve-WslTool -Lock $lock -ToolName $t -Latest:$Latest -Tag $Tag -Version $Version
            Write-Host "===== $($r.Tool) ($($r.Tag)) =====" -ForegroundColor Cyan
            "  asset : $($r.AssetName)"
            "  size  : {0:N0} B ({1:N1} MB)" -f $r.AssetSize, ($r.AssetSize / 1MB)
            "  url   : $($r.AssetUrl)"
        }
    }

    'pin' {
        foreach ($t in (Get-WslTools -Lock $lock -ToolArg $Tool)) {
            if (-not $Latest -and -not $Tag -and -not $Version) {
                $d = $lock.Tools[$t]
                if (-not $d.Tag) {
                    Write-Host "[INFO] $t 未 pin，自动 pin 最新版" -ForegroundColor Yellow
                    $r = Resolve-WslTool -Lock $lock -ToolName $t -Latest
                } else {
                    "  $t : $($d.Version) ($($d.Tag))  sha256=$($d.Sha256)"
                    continue
                }
            } else {
                $r = Resolve-WslTool -Lock $lock -ToolName $t -Latest:$Latest -Tag $Tag -Version $Version
            }
            Set-WslPin -Lock $lock -Resolution $r
        }
    }

    'install' {
        foreach ($t in (Get-WslTools -Lock $lock -ToolArg $Tool)) {
            $r = Resolve-WslTool -Lock $lock -ToolName $t -Latest:$Latest -Tag $Tag -Version $Version
            Install-WslTool -Lock $lock -Resolution $r -DistroName $distro -UserArg $user -Force:$Force
        }
    }

    'update' {
        foreach ($t in (Get-WslTools -Lock $lock -ToolArg $Tool)) {
            $r = Resolve-WslTool -Lock $lock -ToolName $t -Latest
            if ($r.Tag -eq $lock.Tools[$t].Tag) {
                Write-Host "[INFO] $t 已是最新: $($lock.Tools[$t].Version)" -ForegroundColor DarkGray
                continue
            }
            Install-WslTool -Lock $lock -Resolution $r -DistroName $distro -UserArg $user -UpdateLock -Force:$Force
        }
    }

    'status' {
        Write-Host "distro: $distro (user=$user)" -ForegroundColor Cyan
        Write-Host "EnvRoot: $($lock.EnvRoot)" -ForegroundColor DarkGray
        foreach ($t in (@($lock.Tools.Keys | Sort-Object))) {
            $d = $lock.Tools[$t]
            $installed = Get-WslInstalledVersion -Lock $lock -ToolName $t -DistroName $distro -UserArg $user
            $sha = if ($d.Sha256) { $d.Sha256.Substring(0, [math]::Min(16, $d.Sha256.Length)) + '...' } else { '(未回填)' }
            "  $t : locked=$($d.Version) ($($d.Tag))  installed=$(if ($installed) { $installed } else { '-' })  sha256=$sha"
        }
    }

    default { Show-WslHelp }
}
