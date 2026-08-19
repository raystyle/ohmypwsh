#Requires -Version 7.0
# helpers.ps1 - 环境依赖管理核心函数（ohmyenv CLI 共用）
# 设计原则：bootstrap 不依赖 gh，全部通过 api.github.com 查询与直连下载。

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 合并 Machine + User PATH（registry 为最新权威，进程继承的旧 PATH 可能缺新目录）
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

$script:LockPath = Join-Path $PSScriptRoot 'env.psd1'
$script:ToolNames = @('gh', 'git', 'age', 'sops', 'codex', 'aria2')

function New-ToolDef {
    param([Parameter(Mandatory)][string]$Tool)
    switch ($Tool) {
        'gh' {
            @{
                Repo         = 'cli/cli'
                AssetPattern = '^gh_[0-9.]+_windows_amd64\.zip$'
                Dir          = 'gh'
                Bin          = 'gh\bin'
                Exe          = 'gh\bin\gh.exe'
                Extract      = 'zip'
            }
        }
        'git' {
            @{
                Repo         = 'git-for-windows/git'
                AssetPattern = '^PortableGit-[0-9.]+-64-bit\.7z\.exe$'
                Dir          = 'git'
                Bin          = 'git\cmd'
                Exe          = 'git\cmd\git.exe'
                Extract      = '7zsfx'
            }
        }
        'age' {
            @{
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
        'aria2' {
            @{
                TagPrefix    = 'release-'
                Repo         = 'aria2/aria2'
                AssetPattern = '^aria2-[0-9.]+-win-64bit-build1\.zip$'
                Dir          = 'aria2'
                Bin          = 'aria2'
                Exe          = 'aria2\aria2c.exe'
                Extract      = 'zip'
            }
        }
        default { throw "未知工具: $Tool" }
    }
}

function New-DefaultLock {
    $tools = @{}
    foreach ($t in $script:ToolNames) { $tools[$t] = New-ToolDef $t }
    @{ EnvRoot = 'D:\ohmyenv'; Tools = $tools }
}

function Get-EnvLock {
    if (Test-Path $script:LockPath) {
        $lock = Import-PowerShellDataFile -Path $script:LockPath
    } else {
        $lock = New-DefaultLock
        Save-EnvLock -Lock $lock
    }
    foreach ($t in $script:ToolNames) {
        if (-not $lock.Tools.ContainsKey($t)) {
            $lock.Tools[$t] = New-ToolDef $t
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
        $lines.Add("        $t = @{")
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

function Get-GitHubRelease {
    <#
    .SYNOPSIS
        查询 GitHub 发布信息（latest 或指定 tag），带重试。
    #>
    param(
        [Parameter(Mandatory)][string]$Repo,
        [string]$Tag,
        [switch]$Latest
    )
    $headers = @{ 'User-Agent' = 'ohmypwsh-bootstrap'; 'Accept' = 'application/vnd.github+json' }
    $uri = if ($Latest) {
        "https://api.github.com/repos/$Repo/releases/latest"
    } else {
        "https://api.github.com/repos/$Repo/releases/tags/$Tag"
    }
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            return Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 30
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
    if ($version.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
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
    $line = (& $ExePath --version 2>&1 | Select-Object -First 1) -join ' '
    switch ($Tool) {
        'gh'   { if ($line -match 'gh version (\d+\.\d+\.\d+)') { return $Matches[1] } }
        'git'  { if ($line -match 'git version (\S+)') { return $Matches[1] } }
        'age'  { if ($line -match '^v?(\d+\.\d+\.\d+)') { return $Matches[1] } }
        'sops' { if ($line -match 'sops[ -]v?(\d+\.\d+\.\d+)') { return $Matches[1] } }
        'codex' { if ($line -match 'codex-cli\s+v?(\d+\.\d+\.\d+)') { return $Matches[1] } }
        'aria2' { if ($line -match 'aria2 version (\d+\.\d+\.\d+)') { return $Matches[1] } }
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
    $installDir = Join-Path $envRoot $d.Dir
    $cachePath  = Join-Path $envRoot "cache\$($Resolution.AssetName)"
    $exePath    = Join-Path $envRoot $d.Exe
    $shaBackfilled = $false

    if (-not (Test-SafeUnderRoot -Root $envRoot -Path $installDir)) {
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
        if ($RegisterPath) { Add-EnvPath -Dir (Join-Path $envRoot $d.Bin) }
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
    if ($d.Sha256) {
        if ($sha -ne $d.Sha256) { throw "$t 缓存 sha256 与锁定不符" }
    } elseif ($Resolution.Tag -eq $d.Tag) {
        $d.Sha256 = $sha
        $shaBackfilled = $true
    }

    if (Test-Path $installDir) {
        Remove-Item -LiteralPath $installDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null

    switch ($d.Extract) {
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
        }
        default { throw "未知解压类型: $($d.Extract)" }
    }

    $installed = Get-InstalledVersion -ExePath $exePath -Tool $t
    if (-not $installed) { throw "$t 安装后未找到可执行文件或无法读取版本: $exePath" }
    if ($installed -ne $Resolution.Version) {
        throw "$t 版本不符: 期望 $($Resolution.Version)，实际 $installed"
    }
    Write-Host "[OK] $t 安装完成: $installed @ $exePath" -ForegroundColor Green
    if ($shaBackfilled) { Save-EnvLock -Lock $Lock }

    if ($RegisterPath) { Add-EnvPath -Dir (Join-Path $envRoot $d.Bin) }
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
