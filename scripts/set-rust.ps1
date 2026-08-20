#Requires -Version 7.0
# set-rust.ps1 - Rust 接管（rustup + stable + rsproxy.cn 镜像，幂等）
# 参考 D:\hyper-v-lab 的 reverse-engineering-toolchain.md「4) Rust」与
# D:\Oh-My-Claude\.scripts\dev\rust.ps1。
# 用法: pwsh -NoProfile -File scripts\set-rust.ps1
# 前置: 无（本脚本自行下载 rustup-init.exe；VS Build Tools 建议先装，msvc 工具链需要 link.exe）

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')   # 重建 PATH（注册表权威）+ Get-DefaultEnvRoot

$envRoot    = Get-DefaultEnvRoot
$rustHome   = Join-Path $envRoot 'rust'
$rustupHome = Join-Path $rustHome '.rustup'
$cargoHome  = Join-Path $rustHome '.cargo'
$cargoBin   = Join-Path $cargoHome 'bin'
$rustcExe   = Join-Path $cargoBin 'rustc.exe'
$cargoExe   = Join-Path $cargoBin 'cargo.exe'
$initExe    = Join-Path $envRoot 'cache\rustup-init.exe'
$initUrl    = 'https://rsproxy.cn/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe'

New-Item -ItemType Directory -Path $rustHome -Force | Out-Null

# ── 1. 用户环境变量（rsproxy 镜像 + 安装根重定位到 EnvRoot）──
$envVars = @(
    @('RUSTUP_DIST_SERVER', 'https://rsproxy.cn'),
    @('RUSTUP_UPDATE_ROOT', 'https://rsproxy.cn/rustup'),
    @('RUSTUP_HOME', $rustupHome),
    @('CARGO_HOME', $cargoHome)
)
foreach ($kv in $envVars) {
    $name = $kv[0]; $val = $kv[1]
    if ([Environment]::GetEnvironmentVariable($name, 'User') -ne $val) {
        [Environment]::SetEnvironmentVariable($name, $val, 'User')
        Write-Host "[OK] $name = $val" -ForegroundColor Green
    }
    Set-Item "Env:$name" $val
}

# ── 2. 安装 rustup（已装则跳过）──
if ((Test-Path -LiteralPath $rustcExe) -and (& $rustcExe --version 2>$null)) {
    Write-Host '[INFO] rustc 已安装，跳过 rustup-init' -ForegroundColor DarkGray
} else {
    if (-not (Test-Path -LiteralPath $initExe)) {
        Save-ReleaseAsset -Url $initUrl -OutFile $initExe
    }
    Write-Host '[INFO] 运行 rustup-init（stable / x86_64-pc-windows-msvc）...' -ForegroundColor Cyan
    $p = Start-Process -FilePath $initExe -ArgumentList @(
        '-y', '--default-toolchain', 'stable',
        '--default-host', 'x86_64-pc-windows-msvc', '--no-modify-path'
    ) -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0) { throw "rustup-init 失败 exit=$($p.ExitCode)" }
}

# ── 3. cargo 镜像（rsproxy sparse，幂等写入）──
$cargoCfg = Join-Path $cargoHome 'config.toml'
New-Item -ItemType Directory -Path $cargoHome -Force | Out-Null
$cargoContent = @'
[source.crates-io]
replace-with = "rsproxy"

[source.rsproxy]
registry = "sparse+https://rsproxy.cn/index/"

[net]
git-fetch-with-cli = true

[http]
check-revoke = false
multiplexing = true
'@
$existing = if (Test-Path -LiteralPath $cargoCfg) { [System.IO.File]::ReadAllText($cargoCfg) } else { '' }
if ($existing -ne $cargoContent) {
    [System.IO.File]::WriteAllText($cargoCfg, $cargoContent, (New-Object System.Text.UTF8Encoding $false))
    Write-Host '[OK] cargo 镜像已写入 config.toml' -ForegroundColor Green
} else {
    Write-Host '[INFO] cargo 镜像已是最新' -ForegroundColor DarkGray
}

# ── 4. PATH（用户级前置 cargo bin）──
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = $userPath -split ';' | Where-Object { $_ }
if ($parts -notcontains $cargoBin) {
    [Environment]::SetEnvironmentVariable('Path', (@($cargoBin) + $parts) -join ';', 'User')
    $env:Path = "$cargoBin;$env:Path"
    Write-Host '[OK] PATH 已前置 cargo bin' -ForegroundColor Green
} else {
    Write-Host '[INFO] cargo bin 已在 PATH' -ForegroundColor DarkGray
}

# ── 5. 校验 ──
$rustcVer = (& $rustcExe --version 2>&1 | Out-String).Trim()
$cargoVer = (& $cargoExe --version 2>&1 | Out-String).Trim()
Write-Host "[OK] rustc : $rustcVer" -ForegroundColor Green
Write-Host "[OK] cargo : $cargoVer" -ForegroundColor Green
if ($rustcVer -notmatch '\d+\.\d+\.\d+') { throw 'rustc 版本校验失败' }
Write-Host '[完成] Rust 接管就绪。新终端或 `. $PROFILE` 后可用 rustc / cargo。' -ForegroundColor Cyan
