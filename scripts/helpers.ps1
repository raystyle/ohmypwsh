#Requires -Version 7.0
# helpers.ps1 - 环境依赖管理核心函数（ohmyenv CLI 共用）
# 设计原则：bootstrap 不依赖 gh，全部通过 api.github.com 查询与直连下载。

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 合并 Machine + User PATH（registry 为最新权威，进程继承的旧 PATH 可能缺新目录）
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

$script:LockPath = Join-Path $PSScriptRoot 'env.psd1'
# 工具分层：核心基础工具（密钥 key / 智能体环境 agent / 项目管理 project / 基础工具 base）
#           + 扩展工具 extras；ToolNames 顺序 = 引导安装/展示/日常更新顺序（核心先装齐，再稳定扩展）
$script:ToolNames = @('pwsh', 'age', 'sops', 'codex', 'git', 'gh', 'aria2', '7z', 'uv', 'python', 'rg', 'jq', 'yq', 'rmux', 'starship')
$script:ToolCategories = @{
    key     = '密钥'
    agent   = '智能体环境'
    project = '项目管理'
    base    = '基础工具'
    extras  = '扩展工具'
}

function New-ToolDef {
    param([Parameter(Mandatory)][string]$Tool)
    switch ($Tool) {
        'pwsh' {
            @{
                Category     = 'agent'
                Kind         = 'installer'
                Repo         = 'PowerShell/PowerShell'
                AssetPattern = '^PowerShell-[0-9.]+-win-x64\.msi$'
                SumsAsset    = 'hashes.sha256'
                SumsPattern  = 'PowerShell-[0-9.]+-win-x64\.msi'
                Dir          = 'pwsh'
                Bin          = ''
                Exe          = '%LOCALAPPDATA%\Programs\PowerShell\7\pwsh.exe'
                Extract      = 'msi'
            }
        }
        'age' {
            @{
                Category     = 'key'
                Repo         = 'FiloSottile/age'
                AssetPattern = '^age-v[0-9.]+-windows-amd64\.zip$'
                Dir          = 'age'
                Bin          = 'age'
                Exe          = 'age\age.exe'
                Extract      = 'zip'
            }
        }
        'sops' {
            @{
                Category     = 'key'
                Repo         = 'getsops/sops'
                AssetPattern = '^sops-v[0-9.]+\.amd64\.exe$'
                Dir          = 'sops'
                Bin          = 'sops'
                Exe          = 'sops\sops.exe'
                Extract      = 'copy'
            }
        }
        'codex' {
            @{
                Category     = 'agent'
                Kind         = 'installer'
                TagPrefix    = 'rust-v'
                Repo         = 'openai/codex'
                AssetPattern = '^codex-package-x86_64-pc-windows-msvc\.tar\.gz$'
                SumsAsset    = 'codex-package_SHA256SUMS'
                SumsPattern  = 'codex-package-x86_64-pc-windows-msvc\.tar\.gz'
                Dir          = 'codex'
                Bin          = 'codex\bin'
                Exe          = 'codex\bin\codex.exe'
                Extract      = 'targz'
            }
        }
        'git' {
            @{
                Category     = 'project'
                Kind         = 'installer'
                Repo         = 'git-for-windows/git'
                AssetPattern = '^PortableGit-[0-9.]+-64-bit\.7z\.exe$'
                Dir          = 'git'
                Bin          = 'git\cmd'
                Exe          = 'git\cmd\git.exe'
                Extract      = '7zsfx'
            }
        }
        'gh' {
            @{
                Category     = 'project'
                Repo         = 'cli/cli'
                AssetPattern = '^gh_[0-9.]+_windows_amd64\.zip$'
                Dir          = 'gh'
                Bin          = 'gh\bin'
                Exe          = 'gh\bin\gh.exe'
                Extract      = 'zip'
            }
        }
        'aria2' {
            @{
                Category     = 'base'
                TagPrefix    = 'release-'
                Repo         = 'aria2/aria2'
                AssetPattern = '^aria2-[0-9.]+-win-64bit-build1\.zip$'
                Dir          = 'aria2'
                Bin          = 'aria2'
                Exe          = 'aria2\aria2c.exe'
                Extract      = 'zip'
            }
        }
        '7z' {
            @{
                Category       = 'base'
                Repo           = 'ip7z/7zip'
                AssetPattern   = '^7z[0-9]+-extra\.7z$'
                BootstrapAsset = '7zr.exe'
                Dir            = '7z'
                Bin            = '7z'
                Exe            = '7z\7z.exe'
                Extract        = '7z-extra'
            }
        }
        'uv' {
            @{
                Category     = 'base'
                Repo         = 'astral-sh/uv'
                AssetPattern = '^uv-x86_64-pc-windows-msvc\.zip$'
                Dir          = 'uv'
                Bin          = 'uv'
                Exe          = 'uv\uv.exe'
                Extract      = 'zip'
            }
        }
        'python' {
            @{
                Category       = 'base'
                Repo           = 'astral-sh/python-build-standalone'
                AssetPattern   = '^cpython-3\.12\.[0-9]+(\+[0-9]+)?-x86_64-pc-windows-msvc-install_only\.tar\.gz$'
                VersionPattern = '^cpython-(\d+\.\d+\.\d+)'
                Dir            = 'python'
                Bin            = 'python'
                Exe            = 'python\python.exe'
                Extract        = 'targz'
            }
        }
        'rg' {
            @{
                Category     = 'extras'
                Repo         = 'BurntSushi/ripgrep'
                AssetPattern = '^ripgrep-[0-9.]+-x86_64-pc-windows-msvc\.zip$'
                Dir          = 'rg'
                Bin          = 'rg'
                Exe          = 'rg\rg.exe'
                Extract      = 'zip'
            }
        }
        'jq' {
            @{
                Category     = 'extras'
                TagPrefix    = 'jq-'
                Repo         = 'jqlang/jq'
                AssetPattern = '^jq-windows-amd64\.exe$'
                Dir          = 'jq'
                Bin          = 'jq'
                Exe          = 'jq\jq.exe'
                Extract      = 'copy'
            }
        }
        'yq' {
            @{
                Category     = 'extras'
                Repo         = 'mikefarah/yq'
                AssetPattern = '^yq_windows_amd64\.exe$'
                Dir          = 'yq'
                Bin          = 'yq'
                Exe          = 'yq\yq.exe'
                Extract      = 'copy'
            }
        }
        'rmux' {
            @{
                Category     = 'extras'
                Repo         = 'Helvesec/rmux'
                AssetPattern = '^rmux-[0-9.]+-windows-x86_64\.zip$'
                SumsAsset    = 'SHA256SUMS'
                SumsPattern  = 'rmux-[0-9.]+-windows-x86_64\.zip'
                Dir          = 'rmux'
                Bin          = 'rmux'
                Exe          = 'rmux\rmux.exe'
                Extract      = 'zip'
            }
        }
        'starship' {
            @{
                Category     = 'extras'
                Repo         = 'starship/starship'
                AssetPattern = '^starship-x86_64-pc-windows-msvc\.zip$'
                Dir          = 'starship'
                Bin          = 'starship'
                Exe          = 'starship\starship.exe'
                Extract      = 'zip'
            }
        }
        default { throw "未知工具: $Tool" }
    }
}

function Get-DefaultEnvRoot {
    <#
    .SYNOPSIS
        EnvRoot 默认解析：显式环境变量 OHMYENV_ROOT > D 盘（存在）> C 盘（回退）。
    #>
    if ($env:OHMYENV_ROOT -and $env:OHMYENV_ROOT.Trim()) {
        return $env:OHMYENV_ROOT.Trim().TrimEnd('\')
    }
    if (Test-Path 'D:\') { return 'D:\ohmyenv' }
    return 'C:\ohmyenv'
}

function New-DefaultLock {
    $tools = @{}
    foreach ($t in $script:ToolNames) { $tools[$t] = New-ToolDef $t }
    @{ EnvRoot = (Get-DefaultEnvRoot); Tools = $tools }
}

function Get-EnvLock {
    param([string]$EnvRoot)
    if (Test-Path $script:LockPath) {
        $lock = Import-PowerShellDataFile -Path $script:LockPath
    } else {
        $lock = New-DefaultLock
        Save-EnvLock -Lock $lock
    }
    # EnvRoot 覆盖（重定位）：显式 -EnvRoot 参数优先于已有锁定（不覆盖环境变量默认）
    if ($EnvRoot -and $EnvRoot.Trim().TrimEnd('\') -ne $lock.EnvRoot.TrimEnd('\')) {
        $lock.EnvRoot = $EnvRoot.Trim().TrimEnd('\')
    }
    foreach ($t in $script:ToolNames) {
        if (-not $lock.Tools.ContainsKey($t)) {
            $lock.Tools[$t] = New-ToolDef $t
        } else {
            # 静态元数据以 New-ToolDef 为准（同步更新），pin 字段（Version/Tag/Asset/Sha256）保留
            $def = New-ToolDef $t
            foreach ($k in $def.Keys) { $lock.Tools[$t][$k] = $def[$k] }
        }
    }
    $lock
}

function Save-EnvLock {
    param([Parameter(Mandatory)][hashtable]$Lock)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# env.psd1 - 环境依赖锁定清单（由 ohmyenv CLI 维护，勿手改）')
    $lines.Add('@{')
    $lines.Add("    EnvRoot = '$($Lock.EnvRoot)'")
    $lines.Add('    Tools   = @{')
    foreach ($t in $script:ToolNames) {
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
        $lines.Add("            Dir          = '$($d.Dir)'")
        $lines.Add("            Bin          = '$($d.Bin)'")
        $lines.Add("            Exe          = '$($d.Exe)'")
        $lines.Add("            Extract      = '$($d.Extract)'")
        $lines.Add("            Sha256       = '$($d.Sha256)'")
        $lines.Add('        }')
    }
    $lines.Add('    }')
    $lines.Add('}')
    $lines | Set-Content -Path $script:LockPath -Encoding utf8
    Write-Host "[OK] 锁定清单已写入: $script:LockPath" -ForegroundColor Green
}

function Invoke-GitHubApi {
    <#
    .SYNOPSIS
        统一的 api.github.com 调用入口：匿名限流（60/h）时全局走 gh api（认证 5000/h）兜底。
    #>
    param([Parameter(Mandatory)][string]$Uri)
    $headers = @{ 'User-Agent' = 'ohmypwsh-bootstrap'; 'Accept' = 'application/vnd.github+json' }
    try {
        return Invoke-RestMethod -Uri $Uri -Headers $headers -TimeoutSec 30
    } catch {
        if ($_.Exception.Message -match '403|rate limit|502|503|504|Gateway') {
            $ghExe = Get-Command gh.exe -ErrorAction SilentlyContinue
            if ($ghExe) {
                Write-Host '[INFO] 匿名 API 限流，改用 gh api（认证通道）' -ForegroundColor Yellow
                $apiPath = $Uri.Substring('https://api.github.com'.Length)
                $json = & $ghExe.Source api $apiPath 2>$null
                if ($LASTEXITCODE -eq 0 -and $json) {
                    return ($json | ConvertFrom-Json)
                }
            }
        }
        throw
    }
}

function Get-GitHubRelease {
    <#
    .SYNOPSIS
        查询 GitHub 发布信息（latest 或指定 tag），带重试；匿名限流由 Invoke-GitHubApi 全局兜底。
    #>
    param(
        [Parameter(Mandatory)][string]$Repo,
        [string]$Tag,
        [switch]$Latest
    )
    $uri = if ($Latest) {
        "https://api.github.com/repos/$Repo/releases/latest"
    } else {
        "https://api.github.com/repos/$Repo/releases/tags/$Tag"
    }
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            return Invoke-GitHubApi -Uri $uri
        } catch {
            if ($attempt -ge 3) {
                throw "api.github.com 查询失败（$attempt 次）: $uri`n$($_.Exception.Message)"
            }
            $wait = [math]::Pow(2, $attempt)
            Write-Host "[WARN] api.github.com 查询失败，${wait}s 后重试: $($_.Exception.Message)" -ForegroundColor Yellow
            Start-Sleep -Seconds $wait
        }
    }
}

function Find-ReleaseAsset {
    param(
        [Parameter(Mandatory)]$Release,
        [Parameter(Mandatory)][string]$Pattern
    )
    $asset = $Release.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
    if (-not $asset) {
        throw "在 $($Release.tag_name) 中未找到匹配资产: $Pattern"
    }
    $asset
}

function Resolve-ToolVersion {
    <#
    .SYNOPSIS
        通过 api.github.com 解析工具的目标版本与资产（Latest / Tag / Version / 锁定版本）。
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)][string]$Tool,
        [switch]$Latest,
        [string]$Tag,
        [string]$Version
    )
    $d = $Lock.Tools[$Tool]
    if ($Latest) {
        $release = Get-GitHubRelease -Repo $d.Repo -Latest
    } elseif ($Tag) {
        $release = Get-GitHubRelease -Repo $d.Repo -Tag $Tag
    } elseif ($Version) {
        $release = Get-GitHubRelease -Repo $d.Repo -Tag "v$Version"
    } else {
        if (-not $d.Tag) { throw "$Tool 尚未 pin 版本。先执行: ohmyenv pin $Tool -Latest（或 -Version <版本>）" }
        $release = Get-GitHubRelease -Repo $d.Repo -Tag $d.Tag
    }
    $asset = Find-ReleaseAsset -Release $release -Pattern $d.AssetPattern
    $prefix  = if ($d.TagPrefix) { $d.TagPrefix } else { 'v' }
    $version = $release.tag_name
    if ($d.VersionPattern -and $asset.name -match $d.VersionPattern) {
        # 如 python-build-standalone：tag 是日期，版本从资产名提取
        $version = $Matches[1]
    } elseif ($version.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $version = $version.Substring($prefix.Length)
    }
    @{
        Tool      = $Tool
        Tag       = $release.tag_name
        Version   = $version
        AssetName = $asset.name
        AssetSize = $asset.size
        AssetUrl  = $asset.browser_download_url
        Release   = $release
    }
}

function Set-ToolPin {
    <#
    .SYNOPSIS
        将解析结果写入锁定清单（版本管理：先 pin 后 update）。
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)]$Resolution
    )
    $d = $Lock.Tools[$Resolution.Tool]
    $d.Tag     = $Resolution.Tag
    $d.Version = $Resolution.Version
    $d.Asset   = $Resolution.AssetName
    $d.Sha256  = ''
    Save-EnvLock -Lock $Lock
    Write-Host "[OK] $($Resolution.Tool) 已 pin: $($Resolution.Version)（sha256 将在 install/deploy 时回填）" -ForegroundColor Green
}

function Assert-Sha256 {
    param(
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][string]$Expected
    )
    $actual = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash
    if ($actual -ne $Expected) {
        throw "sha256 校验失败: $File`n期望 $Expected`n实际 $actual"
    }
}

function Save-ReleaseAsset {
    <#
    .SYNOPSIS
        下载发布资产到 cache（curl.exe 主通道 + Invoke-WebRequest 兜底），命中缓存则复用。
    #>
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$OutFile,
        [string]$ExpectedSha256
    )
    $outDir = Split-Path -Parent $OutFile
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    if (Test-Path $OutFile) {
        if ($ExpectedSha256) {
            try {
                Assert-Sha256 -File $OutFile -Expected $ExpectedSha256
                Write-Host "[OK] 命中缓存（sha256 一致）: $OutFile" -ForegroundColor Green
                return
            } catch {
                Write-Host "[WARN] 缓存 sha256 不匹配，重新下载: $($_.Exception.Message)" -ForegroundColor Yellow
                Remove-Item -LiteralPath $OutFile -Force
            }
        }
        Write-Host "[INFO] 已有缓存但无 sha256 基准，复用: $OutFile" -ForegroundColor DarkGray
        return
    }

    $aria2 = (Get-Command aria2c.exe -ErrorAction SilentlyContinue).Source
    if ($aria2) {
        $outDir  = Split-Path -Parent $OutFile
        $outName = Split-Path -Leaf $OutFile
        & $aria2 -x 16 -s 16 -k 1M --file-allocation=none --auto-file-renaming=false --allow-overwrite=true --summary-interval=0 --console-log-level=warn -d $outDir -o $outName $Url
        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutFile)) {
            if ($ExpectedSha256) { Assert-Sha256 -File $OutFile -Expected $ExpectedSha256 }
            Write-Host "[OK] 已下载（aria2 多线程）: $OutFile" -ForegroundColor Green
            return
        }
        Write-Host "[WARN] aria2 下载失败（exit=$LASTEXITCODE），改用 curl" -ForegroundColor Yellow
    }

    $curl = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source
    if ($curl) {
        & $curl -L --fail --retry 5 --retry-delay 3 --connect-timeout 20 -sS -o $OutFile $Url
        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutFile)) {
            if ($ExpectedSha256) { Assert-Sha256 -File $OutFile -Expected $ExpectedSha256 }
            Write-Host "[OK] 已下载: $OutFile" -ForegroundColor Green
            return
        }
        Write-Host "[WARN] curl 下载失败（exit=$LASTEXITCODE），改用 Invoke-WebRequest 兜底" -ForegroundColor Yellow
    }
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -TimeoutSec 600 -UseBasicParsing
    if ($ExpectedSha256) { Assert-Sha256 -File $OutFile -Expected $ExpectedSha256 }
    Write-Host "[OK] 已下载（兜底）: $OutFile" -ForegroundColor Green
}

function Get-InstalledVersion {
    param(
        [Parameter(Mandatory)][string]$ExePath,
        [Parameter(Mandatory)][string]$Tool
    )
    if (-not (Test-Path $ExePath)) { return $null }
    $versionArgs = switch ($Tool) {
        '7z'   { @('--help') }
        'rmux' { @('-V') }   # rmux 为 tmux 风格，--version 不支持，用 -V
        default { @('--version') }
    }
    # 跳过空行（如 7z --help 首行为空行）
    $line = (& $ExePath $versionArgs 2>&1 | Where-Object { $_ -and $_.Trim() } | Select-Object -First 1) -join ' '
    switch ($Tool) {
        'pwsh'  { if ($line -match 'PowerShell\s+(\d+\.\d+\.\d+)') { return $Matches[1] } }
        'gh'   { if ($line -match 'gh version (\d+\.\d+\.\d+)') { return $Matches[1] } }
        'git'  { if ($line -match 'git version (\S+)') { return $Matches[1] } }
        'age'  { if ($line -match '^v?(\d+\.\d+\.\d+)') { return $Matches[1] } }
        'sops' { if ($line -match 'sops[ -]v?(\d+\.\d+\.\d+)') { return $Matches[1] } }
        'codex' { if ($line -match 'codex-cli\s+v?(\d+\.\d+\.\d+)') { return $Matches[1] } }
        'aria2' { if ($line -match 'aria2 version (\d+\.\d+\.\d+)') { return $Matches[1] } }
        '7z'    { if ($line -match '7-Zip\s+(\d+\.\d+)') { return $Matches[1] } }
        'uv'    { if ($line -match 'uv (\d+\.\d+\.\d+)') { return $Matches[1] } }
        'python' { if ($line -match 'Python (\d+\.\d+\.\d+)') { return $Matches[1] } }
        'rg'    { if ($line -match 'ripgrep (\d+\.\d+\.\d+)') { return $Matches[1] } }
        'jq'    { if ($line -match 'jq-(\d+\.\d+\.\d+)') { return $Matches[1] } }
        'yq'    { if ($line -match 'version v?(\d+\.\d+\.\d+)') { return $Matches[1] } }
        'rmux'  { if ($line -match 'rmux (\d+\.\d+\.\d+)') { return $Matches[1] } }
        'starship' { if ($line -match 'starship (\d+\.\d+\.\d+)') { return $Matches[1] } }
    }
    $null
}

function Test-SafeUnderRoot {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Install-ToolVersion {
    <#
    .SYNOPSIS
        下载 -> 校验 -> 解压 -> 验证版本，可选注册 PATH / 更新锁定。
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)]$Resolution,
        [switch]$RegisterPath,
        [switch]$UpdateLock,
        [switch]$Force
    )
    $t  = $Resolution.Tool
    $d  = $Lock.Tools[$t]
    $envRoot    = $Lock.EnvRoot
    $isMsi      = ($d.Extract -eq 'msi')
    $installDir = if ($isMsi) { $null } else { Join-Path $envRoot $d.Dir }
    $cachePath  = Join-Path $envRoot "cache\$($Resolution.AssetName)"
    $exePath    = if ($isMsi) { [Environment]::ExpandEnvironmentVariables($d.Exe) } else { Join-Path $envRoot $d.Exe }
    $shaBackfilled = $false

    if (-not $isMsi -and -not (Test-SafeUnderRoot -Root $envRoot -Path $installDir)) {
        throw "危险路径，拒绝操作: $installDir"
    }

    Write-Host "===== $t ($($Resolution.Tag)) ====="

    $cur = Get-InstalledVersion -ExePath $exePath -Tool $t
    if (-not $Force -and $cur -eq $Resolution.Version) {
        Write-Host "[INFO] $t $($Resolution.Version) 已安装，跳过（-Force 强制重装）" -ForegroundColor DarkGray
        if (-not $d.Sha256 -and (Test-Path $cachePath)) {
            $d.Sha256 = (Get-FileHash -LiteralPath $cachePath -Algorithm SHA256).Hash
            Save-EnvLock -Lock $Lock
            Write-Host "[OK] 已回填 sha256（命中缓存）" -ForegroundColor Green
        }
        if ($RegisterPath -and $d.Bin) { Add-EnvPath -Dir (Join-Path $envRoot $d.Bin) }
        if ($UpdateLock -and $d.Tag -ne $Resolution.Tag) {
            # 已安装版本与解析一致但锁定滞后（如上次安装中断）：补齐锁定
            $d.Tag     = $Resolution.Tag
            $d.Version = $Resolution.Version
            $d.Asset   = $Resolution.AssetName
            if (Test-Path $cachePath) { $d.Sha256 = (Get-FileHash -LiteralPath $cachePath -Algorithm SHA256).Hash }
            Save-EnvLock -Lock $Lock
            Write-Host "[OK] $t 已锁定: $($d.Version)（补齐滞后锁定）" -ForegroundColor Green
        }
        return
    }

    $expectedSha = if ($d.Sha256 -and $Resolution.Tag -eq $d.Tag) { $d.Sha256 } else { '' }
    if (-not $expectedSha -and $d.SumsAsset -and $Resolution.Tag -eq $d.Tag) {
        # 从官方 SHA256SUMS 取期望校验值（资产名不含版本，必须按清单校验）
        $sumsPath = Join-Path $envRoot "cache\$($d.SumsAsset)"
        $sumsUrl  = "https://github.com/$($d.Repo)/releases/download/$($Resolution.Tag)/$($d.SumsAsset)"
        if (Test-Path $sumsPath) { Remove-Item -LiteralPath $sumsPath -Force }
        Save-ReleaseAsset -Url $sumsUrl -OutFile $sumsPath
        $sumLine = Get-Content $sumsPath | Where-Object { $_ -match $d.SumsPattern } | Select-Object -First 1
        if ($sumLine -match '([0-9a-fA-F]{64})\s') { $expectedSha = $Matches[1].ToUpperInvariant() }
        if (-not $expectedSha) { throw "$t SHA256SUMS 中未找到匹配资产: $($d.SumsPattern)" }
    }
    Save-ReleaseAsset -Url $Resolution.AssetUrl -OutFile $cachePath -ExpectedSha256 $expectedSha

    $sha = (Get-FileHash -LiteralPath $cachePath -Algorithm SHA256).Hash
    if ($Resolution.Tag -eq $d.Tag) {
        if ($d.Sha256 -and $sha -ne $d.Sha256) { throw "$t 缓存 sha256 与锁定不符" }
        if (-not $d.Sha256) { $d.Sha256 = $sha; $shaBackfilled = $true }
    } else {
        # 升级/换版本：锁定 sha 属于旧版本，接受新下载的校验值并回填
        $d.Sha256 = $sha
        $shaBackfilled = $true
    }

    if (-not $isMsi) {
        if (Test-Path $installDir) {
            Remove-Item -LiteralPath $installDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    switch ($d.Extract) {
        'msi' {
            # 安装包：per-user 静默安装（不需管理员、可迁移），不绿色解压；MSI 自行注册用户 PATH
            $perUserTarget = Join-Path $env:LOCALAPPDATA 'Programs\PowerShell\7'
            $msiArgs = "/i `"$cachePath`" /qn /norestart MSIINSTALLPERUSER=1 APPLICATIONFOLDER=`"$perUserTarget`""
            Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait
            if ($LASTEXITCODE -ne 0) { throw "$t MSI 安装失败（exit=$LASTEXITCODE）" }
        }
        'zip' {
            Expand-Archive -Path $cachePath -DestinationPath $installDir -Force
            # 展平顶层单目录（如 age zip 的 age/ 包裹层）
            $items = Get-ChildItem -LiteralPath $installDir -Force
            $dirs  = @($items | Where-Object { $_.PSIsContainer })
            $files = @($items | Where-Object { -not $_.PSIsContainer })
            if ($files.Count -eq 0 -and $dirs.Count -eq 1) {
                $inner = $dirs[0].FullName
                Get-ChildItem -LiteralPath $inner -Force | Move-Item -Destination $installDir -Force
                Remove-Item -LiteralPath $inner -Force
            }
        }
        '7zsfx' {
            & $cachePath '-y' "-o$installDir"
            if ($LASTEXITCODE -ne 0) { throw "$t 自解压失败（exit=$LASTEXITCODE）" }
        }
        'copy' {
            Copy-Item -LiteralPath $cachePath -Destination (Join-Path $installDir (Split-Path -Leaf $d.Exe)) -Force
        }
        'targz' {
            tar -xzf $cachePath -C $installDir
            if ($LASTEXITCODE -ne 0) { throw "$t tar.gz 解压失败（exit=$LASTEXITCODE）" }
            # 展平顶层单目录（如 python-build-standalone 的 python/ 包裹层）
            $items = Get-ChildItem -LiteralPath $installDir -Force
            $dirs  = @($items | Where-Object { $_.PSIsContainer })
            $files = @($items | Where-Object { -not $_.PSIsContainer })
            if ($files.Count -eq 0 -and $dirs.Count -eq 1) {
                $inner = $dirs[0].FullName
                Get-ChildItem -LiteralPath $inner -Force | Move-Item -Destination $installDir -Force
                Remove-Item -LiteralPath $inner -Force
            }
        }
        '7z-archive' {
            # 7zXXX-x64.exe 是 7z 归档（直接运行需提权）；Windows 自带 tar(bsdtar) 可直接解包，无需预装 7z
            tar -xf $cachePath -C $installDir
            if ($LASTEXITCODE -ne 0) { throw "$t 7z 归档解包失败（exit=$LASTEXITCODE）" }
        }
        default { throw "未知解压类型: $($d.Extract)" }
    }

    # 7zsfx 等解包后文件/杀软可能瞬态未就绪，版本读取加重试
    $installed = $null
    for ($i = 1; $i -le 5; $i++) {
        $installed = Get-InstalledVersion -ExePath $exePath -Tool $t
        if ($installed) { break }
        Start-Sleep -Milliseconds (500 * $i)
    }
    if (-not $installed) { throw "$t 安装后未找到可执行文件或无法读取版本: $exePath" }
    if ($installed -ne $Resolution.Version) {
        throw "$t 版本不符: 期望 $($Resolution.Version)，实际 $installed"
    }
    Write-Host "[OK] $t 安装完成: $installed @ $exePath" -ForegroundColor Green
    if ($shaBackfilled) { Save-EnvLock -Lock $Lock }

    if ($RegisterPath -and $d.Bin) { Add-EnvPath -Dir (Join-Path $envRoot $d.Bin) }
    if ($UpdateLock) {
        $d.Tag    = $Resolution.Tag
        $d.Version = $Resolution.Version
        $d.Asset   = $Resolution.AssetName
        $d.Sha256  = $sha
        Save-EnvLock -Lock $Lock
        Write-Host "[OK] $t 已锁定: $($d.Version)" -ForegroundColor Green
    }
}

function Add-EnvPath {
    <#
    .SYNOPSIS
        用户 PATH 幂等前置注册（保证优先于旧条目），并同步当前进程。
    #>
    param([Parameter(Mandatory)][string]$Dir)
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = $user -split ';' | Where-Object { $_ }
    if ($parts -contains $Dir) {
        Write-Host "[INFO] PATH 已存在，跳过: $Dir" -ForegroundColor DarkGray
        return
    }
    $new = (@($Dir) + $parts) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $new, 'User')
    $env:Path = "$Dir;$env:Path"
    Write-Host "[OK] PATH 已注册（前置）: $Dir" -ForegroundColor Green
}

function Remove-EnvPath {
    param([Parameter(Mandatory)][string]$Dir)
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = $user -split ';' | Where-Object { $_ -and $_ -ne $Dir }
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
    $env:Path = (($env:Path -split ';') | Where-Object { $_ -and $_ -ne $Dir }) -join ';'
    Write-Host "[OK] PATH 已移除: $Dir" -ForegroundColor Green
}

function Invoke-EnvPack {
    <#
    .SYNOPSIS
        打包部署压缩包：密钥 + 绿色部署包 + 安装包 + 部署器脚本 + manifest。
        产物输出到 EnvRoot\deploy\ohmyenv-deploy-<时间戳>.zip。
    #>
    param([Parameter(Mandatory)][hashtable]$Lock)

    $envRoot   = $Lock.EnvRoot
    $deployDir = Join-Path $envRoot 'deploy'
    New-Item -ItemType Directory -Path $deployDir -Force | Out-Null

    $stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
    $zipPath = Join-Path $deployDir "ohmyenv-deploy-$stamp.zip"
    $stage   = Join-Path $env:TEMP "ohmyenv-pack-$stamp"
    New-Item -ItemType Directory -Path $stage -Force | Out-Null

    $portableDir  = Join-Path $stage 'portable'
    $installerDir = Join-Path $stage 'installers'
    $secretsDir   = Join-Path $stage 'secrets'
    $scriptsDir   = Join-Path $stage 'scripts'
    foreach ($d in @($portableDir, $installerDir, $secretsDir, $scriptsDir)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }

    $manifest = [ordered]@{ Created = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'); EnvRoot = $envRoot; Tools = [ordered]@{} }

    foreach ($t in $script:ToolNames) {
        $d = $Lock.Tools[$t]
        $kind = if ($d.Kind) { $d.Kind } else { 'portable' }
        if ($kind -eq 'installer') {
            # 安装包：归档 cache 里的原始 installer（含 BootstrapAsset 如 7zr.exe）
            $cacheFile = Join-Path $envRoot "cache\$($d.Asset)"
            if (Test-Path -LiteralPath $cacheFile) {
                Copy-Item -LiteralPath $cacheFile -Destination (Join-Path $installerDir $d.Asset) -Force
                Write-Host "[打包] installer: $t ($($d.Asset))" -ForegroundColor Cyan
            } else {
                Write-Host "[跳过] installer 缓存缺失: $t ($($d.Asset))" -ForegroundColor Yellow
            }
            if ($d.BootstrapAsset) {
                $boot = Join-Path $envRoot "cache\$($d.BootstrapAsset)"
                if (Test-Path -LiteralPath $boot) {
                    Copy-Item -LiteralPath $boot -Destination (Join-Path $installerDir $d.BootstrapAsset) -Force
                }
            }
        } else {
            # 部署包：归档 EnvRoot 下的绿色产物目录
            $src = Join-Path $envRoot $d.Dir
            if (Test-Path -LiteralPath $src) {
                Copy-Item -LiteralPath $src -Destination (Join-Path $portableDir $d.Dir) -Recurse -Force
                Write-Host "[打包] portable: $t" -ForegroundColor Cyan
            } else {
                Write-Host "[跳过] portable 缺失: $t ($src)" -ForegroundColor Yellow
            }
        }
        $manifest.Tools[$t] = [ordered]@{ Version = $d.Version; Tag = $d.Tag; Asset = $d.Asset; Sha256 = $d.Sha256; Kind = $kind }
    }

    # 密钥：SOPS 加密副本 + age 私钥（明文 API key 永不进包）
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $secretsSrc = Join-Path $projectRoot '.secrets'
    if (Test-Path -LiteralPath $secretsSrc) {
        Get-ChildItem -LiteralPath $secretsSrc -File | Copy-Item -Destination $secretsDir -Force
        Write-Host '[打包] secrets: .secrets 加密副本' -ForegroundColor Cyan
    }
    $ageKey = Join-Path $env:APPDATA 'sops\age\keys.txt'
    if (Test-Path -LiteralPath $ageKey) {
        Copy-Item -LiteralPath $ageKey -Destination (Join-Path $secretsDir 'age-keys.txt') -Force
        Write-Host '[打包] secrets: age 私钥' -ForegroundColor Cyan
    }

    # agent 配置（排除 credentials/auth 等敏感状态，只带可迁移配置模板）
    $configDir = Join-Path $stage 'config'
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null

    $codexHome = Join-Path $env:USERPROFILE '.codex'
    if (Test-Path -LiteralPath (Join-Path $codexHome 'config.toml')) { Copy-Item -LiteralPath (Join-Path $codexHome 'config.toml') -Destination (Join-Path $configDir 'codex-config.toml') -Force }
    if (Test-Path -LiteralPath (Join-Path $codexHome 'models.json')) { Copy-Item -LiteralPath (Join-Path $codexHome 'models.json') -Destination (Join-Path $configDir 'codex-models.json') -Force }
    if (Test-Path -LiteralPath (Join-Path $codexHome 'skills')) { Copy-Item -LiteralPath (Join-Path $codexHome 'skills') -Destination (Join-Path $configDir 'codex-skills') -Recurse -Force }

    $claudeHome = Join-Path $env:USERPROFILE '.claude'
    if (Test-Path -LiteralPath (Join-Path $claudeHome 'settings.json')) { Copy-Item -LiteralPath (Join-Path $claudeHome 'settings.json') -Destination (Join-Path $configDir 'claude-settings.json') -Force }
    if (Test-Path -LiteralPath (Join-Path $claudeHome 'skills')) { Copy-Item -LiteralPath (Join-Path $claudeHome 'skills') -Destination (Join-Path $configDir 'claude-skills') -Recurse -Force }
    $claudeJson = Join-Path $env:USERPROFILE '.claude.json'
    if (Test-Path -LiteralPath $claudeJson) { Copy-Item -LiteralPath $claudeJson -Destination (Join-Path $configDir 'claude.json') -Force }

    $kimiHome = Join-Path $env:USERPROFILE '.kimi-code'
    foreach ($kf in @('config.toml', 'tui.toml', 'workspaces.json')) {
        if (Test-Path -LiteralPath (Join-Path $kimiHome $kf)) { Copy-Item -LiteralPath (Join-Path $kimiHome $kf) -Destination (Join-Path $configDir ("kimi-" + $kf)) -Force }
    }
    if (Test-Path -LiteralPath (Join-Path $kimiHome 'workspace-trust')) { Copy-Item -LiteralPath (Join-Path $kimiHome 'workspace-trust') -Destination (Join-Path $configDir 'kimi-workspace-trust') -Recurse -Force }

    $starshipCfg = Join-Path $env:USERPROFILE '.config\starship.toml'
    if (Test-Path -LiteralPath $starshipCfg) { Copy-Item -LiteralPath $starshipCfg -Destination (Join-Path $configDir 'starship.toml') -Force }

    $pwshProfile = Join-Path $env:USERPROFILE 'Documents\PowerShell\profile.ps1'
    if (Test-Path -LiteralPath $pwshProfile) { Copy-Item -LiteralPath $pwshProfile -Destination (Join-Path $configDir 'profile-pwsh.ps1') -Force }
    $ps5Profile = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\profile.ps1'
    if (Test-Path -LiteralPath $ps5Profile) { Copy-Item -LiteralPath $ps5Profile -Destination (Join-Path $configDir 'profile-ps5.ps1') -Force }
    Write-Host '[打包] config: codex/claude/kimi/starship/profile 配置' -ForegroundColor Cyan

    # 部署器脚本（ohmyenv 自身，用于目标机 unpack）
    Copy-Item -Path (Join-Path $PSScriptRoot '*') -Destination $scriptsDir -Recurse -Force

    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $stage 'manifest.json') -Encoding utf8
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -Force
    Remove-Item -LiteralPath $stage -Recurse -Force

    $size = (Get-Item -LiteralPath $zipPath).Length
    Write-Host "[OK] 部署包已产出: $zipPath" -ForegroundColor Green
    "  size : {0:N1} MB" -f ($size / 1MB)
    $zipPath
}

function Invoke-EnvUnpack {
    <#
    .SYNOPSIS
        从部署压缩包离线还原工具环境（幂等）：已装且版本 >= pin 跳过，未装部署，版本低升级。
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)][string]$ZipPath
    )
    if (-not (Test-Path -LiteralPath $ZipPath)) { throw "部署包不存在: $ZipPath" }

    $envRoot = $Lock.EnvRoot
    New-Item -ItemType Directory -Path $envRoot -Force | Out-Null
    $stage = Join-Path $env:TEMP ("ohmyenv-unpack-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null

    try {
        Expand-Archive -LiteralPath $ZipPath -DestinationPath $stage -Force
        $manifest = Get-Content -LiteralPath (Join-Path $stage 'manifest.json') -Raw | ConvertFrom-Json

        foreach ($t in $script:ToolNames) {
            $m = $manifest.Tools.$t
            if (-not $m) { continue }
            $d = $Lock.Tools[$t]
            $kind = if ($m.Kind) { $m.Kind } else { 'portable' }
            $pinVersion = [version]$m.Version

            # 检测目标机已装版本
            $isMsi   = ($d.Extract -eq 'msi')
            $exePath = if ($isMsi) { [Environment]::ExpandEnvironmentVariables($d.Exe) } else { Join-Path $envRoot $d.Exe }
            $installed = Get-InstalledVersion -ExePath $exePath -Tool $t

            # 幂等：已装且版本 >= pin 跳过（版本高不降级）
            if ($installed -and ([version]$installed -ge $pinVersion)) {
                Write-Host "[跳过] $t $installed >= $($m.Version)（幂等）" -ForegroundColor DarkGray
                continue
            }
            $label = if ($installed) { "升级 $installed -> $($m.Version)" } else { "部署 $($m.Version)" }
            Write-Host "[$label] $t" -ForegroundColor Cyan

            if ($kind -eq 'installer') {
                # 安装包：installers/<asset> 复制到 cache 后走本地安装
                $asset = $m.Asset
                $srcInstaller = Join-Path $stage "installers\$asset"
                if (-not (Test-Path -LiteralPath $srcInstaller)) {
                    Write-Host "[跳过] installer 缺失: $asset" -ForegroundColor Yellow
                    continue
                }
                $cacheFile = Join-Path $envRoot "cache\$asset"
                Copy-Item -LiteralPath $srcInstaller -Destination $cacheFile -Force
                if ($d.BootstrapAsset) {
                    $bootSrc = Join-Path $stage "installers\$($d.BootstrapAsset)"
                    if (Test-Path -LiteralPath $bootSrc) {
                        Copy-Item -LiteralPath $bootSrc -Destination (Join-Path $envRoot "cache\$($d.BootstrapAsset)") -Force
                    }
                }
                if ($m.Sha256) { $d.Sha256 = $m.Sha256 }
                # msi（pwsh）自更新会破坏会话：提示用 set-pwsh.ps1 独立处理
                if ($isMsi) {
                    Write-Host "[HINT] $t 是 MSI 安装包，请关闭所有 PowerShell 后运行:" -ForegroundColor Yellow
                    Write-Host "       powershell.exe -NoProfile -ExecutionPolicy Bypass -File $(Join-Path $PSScriptRoot 'set-pwsh.ps1')" -ForegroundColor Yellow
                    continue
                }
                $resolution = @{ Tool = $t; Tag = $m.Tag; Version = $m.Version; AssetName = $asset; AssetUrl = $null; AssetSize = 0; Release = $null }
                Install-ToolVersion -Lock $Lock -Resolution $resolution -RegisterPath -Force
            } else {
                # 部署包：portable/<dir> 解压到 EnvRoot + 幂等注册 PATH
                $src = Join-Path $stage "portable\$($d.Dir)"
                if (-not (Test-Path -LiteralPath $src)) {
                    Write-Host "[跳过] portable 缺失: $($d.Dir)" -ForegroundColor Yellow
                    continue
                }
                $dst = Join-Path $envRoot $d.Dir
                if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
                Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
                if ($d.Bin) { Add-EnvPath -Dir (Join-Path $envRoot $d.Bin) }
                $verify = Get-InstalledVersion -ExePath (Join-Path $envRoot $d.Exe) -Tool $t
                Write-Host "[OK] $t 部署完成: $verify" -ForegroundColor Green
            }
        }

        # 密钥恢复：age 私钥 + .secrets 加密副本
        $projectRoot = Split-Path $PSScriptRoot -Parent
        $ageKeySrc = Join-Path $stage 'secrets\age-keys.txt'
        if (Test-Path -LiteralPath $ageKeySrc) {
            $ageDir = Join-Path $env:APPDATA 'sops\age'
            New-Item -ItemType Directory -Path $ageDir -Force | Out-Null
            Copy-Item -LiteralPath $ageKeySrc -Destination (Join-Path $ageDir 'keys.txt') -Force
            Write-Host '[OK] age 私钥已恢复' -ForegroundColor Green
        }
        $secretsSrc = Join-Path $stage 'secrets'
        $secretsDst = Join-Path $projectRoot '.secrets'
        if (Test-Path -LiteralPath $secretsSrc) {
            New-Item -ItemType Directory -Path $secretsDst -Force | Out-Null
            Get-ChildItem -LiteralPath $secretsSrc -File -Filter *.enc | Copy-Item -Destination $secretsDst -Force
            Write-Host '[OK] .secrets 加密副本已恢复' -ForegroundColor Green
        }

        # agent 配置恢复（幂等写回用户目录）
        $configDir = Join-Path $stage 'config'
        if (Test-Path -LiteralPath $configDir) {
            $codexHome = Join-Path $env:USERPROFILE '.codex'
            New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
            foreach ($kf in @('config.toml', 'models.json')) {
                $src = Join-Path $configDir ("codex-" + $kf)
                if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $codexHome $kf) -Force }
            }
            if (Test-Path -LiteralPath (Join-Path $configDir 'codex-skills')) { Copy-Item -LiteralPath (Join-Path $configDir 'codex-skills') -Destination (Join-Path $codexHome 'skills') -Recurse -Force }

            $claudeHome = Join-Path $env:USERPROFILE '.claude'
            New-Item -ItemType Directory -Path $claudeHome -Force | Out-Null
            if (Test-Path -LiteralPath (Join-Path $configDir 'claude-settings.json')) { Copy-Item -LiteralPath (Join-Path $configDir 'claude-settings.json') -Destination (Join-Path $claudeHome 'settings.json') -Force }
            if (Test-Path -LiteralPath (Join-Path $configDir 'claude-skills')) { Copy-Item -LiteralPath (Join-Path $configDir 'claude-skills') -Destination (Join-Path $claudeHome 'skills') -Recurse -Force }
            if (Test-Path -LiteralPath (Join-Path $configDir 'claude.json')) { Copy-Item -LiteralPath (Join-Path $configDir 'claude.json') -Destination (Join-Path $env:USERPROFILE '.claude.json') -Force }

            $kimiHome = Join-Path $env:USERPROFILE '.kimi-code'
            New-Item -ItemType Directory -Path $kimiHome -Force | Out-Null
            foreach ($kf in @('config.toml', 'tui.toml', 'workspaces.json')) {
                $src = Join-Path $configDir ("kimi-" + $kf)
                if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $kimiHome $kf) -Force }
            }
            if (Test-Path -LiteralPath (Join-Path $configDir 'kimi-workspace-trust')) { Copy-Item -LiteralPath (Join-Path $configDir 'kimi-workspace-trust') -Destination (Join-Path $kimiHome 'workspace-trust') -Recurse -Force }

            if (Test-Path -LiteralPath (Join-Path $configDir 'starship.toml')) {
                $starshipDir = Join-Path $env:USERPROFILE '.config'
                New-Item -ItemType Directory -Path $starshipDir -Force | Out-Null
                Copy-Item -LiteralPath (Join-Path $configDir 'starship.toml') -Destination (Join-Path $starshipDir 'starship.toml') -Force
            }
            if (Test-Path -LiteralPath (Join-Path $configDir 'profile-pwsh.ps1')) {
                $pDir = Join-Path $env:USERPROFILE 'Documents\PowerShell'
                New-Item -ItemType Directory -Path $pDir -Force | Out-Null
                Copy-Item -LiteralPath (Join-Path $configDir 'profile-pwsh.ps1') -Destination (Join-Path $pDir 'profile.ps1') -Force
            }
            if (Test-Path -LiteralPath (Join-Path $configDir 'profile-ps5.ps1')) {
                $pDir = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell'
                New-Item -ItemType Directory -Path $pDir -Force | Out-Null
                Copy-Item -LiteralPath (Join-Path $configDir 'profile-ps5.ps1') -Destination (Join-Path $pDir 'profile.ps1') -Force
            }
            Write-Host '[OK] agent 配置已恢复（codex/claude/kimi/starship/profile）' -ForegroundColor Green
        }

        Write-Host '[OK] unpack 完成' -ForegroundColor Green
    } finally {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}
