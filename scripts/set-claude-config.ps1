#Requires -Version 7.0
# set-claude-config.ps1 - Claude Code 扩展配置（GLM-5.3 1M 上下文，幂等合并）
# 用法: pwsh -NoProfile -File scripts\set-claude-config.ps1

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers.ps1')   # 重建 PATH（注册表权威）

$toolBin = 'D:\ohmyenv\uv-tools\bin'
$claudeExe = Join-Path $toolBin 'claude.exe'

# ── 1. 确保 uv 工具目录环境（进程级，供本次安装使用） ──
foreach ($n in @('UV_TOOL_DIR', 'UV_TOOL_BIN_DIR', 'UV_INSTALL_DIR')) {
    Set-Item "env:$n" ([Environment]::GetEnvironmentVariable($n, 'User'))
}

# ── 2. 安装 claude-code（缺省安装；从 claude-agent-sdk wheel 解出 claude.exe） ──
if (-not (Test-Path -LiteralPath $claudeExe)) {
    Write-Host '[INFO] 下载 claude-agent-sdk wheel 并解出 claude.exe ...' -ForegroundColor Cyan
    $whlDir = Join-Path 'D:\ohmyenv\cache' ("claude-whl-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $whlDir -Force | Out-Null
    try {
        & uv run --no-project --python 3.12 python -m pip download --no-deps --only-binary :all: -d $whlDir claude-agent-sdk
        if ($LASTEXITCODE -ne 0) { throw 'claude-agent-sdk 下载失败' }
        $whl = Get-ChildItem -LiteralPath $whlDir -Filter *.whl | Select-Object -First 1
        if (-not $whl) { throw '未找到 wheel 文件' }
        $zip = Join-Path $whlDir ($whl.BaseName + '.zip')
        Copy-Item -LiteralPath $whl.FullName -Destination $zip
        $extract = Join-Path $whlDir 'extracted'
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
        $srcExe = Get-ChildItem -LiteralPath $extract -Recurse -Filter claude.exe | Select-Object -First 1
        if (-not $srcExe) { throw 'wheel 内未找到 claude.exe' }
        Copy-Item -LiteralPath $srcExe.FullName -Destination $claudeExe -Force
        Write-Host "[OK] claude-code 已安装: $claudeExe" -ForegroundColor Green
    } finally {
        Remove-Item -LiteralPath $whlDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "[OK] claude 已存在: $claudeExe" -ForegroundColor Green
}

# ── 3. 用户环境变量（参考 omc 优化集；不装插件/hook，关遥测） ──
$envVars = [ordered]@{
    'ANTHROPIC_BASE_URL'                          = 'https://open.bigmodel.cn/api/anthropic'
    'DISABLE_TELEMETRY'                           = '1'
    'DISABLE_FEEDBACK_SURVEY'                     = '1'
    'DISABLE_AUTOUPDATER'                         = '1'
    'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC'    = '1'
    'CLAUDE_CODE_DISABLE_1M_CONTEXT'              = '0'
    'CLAUDE_CODE_ATTRIBUTION_HEADER'              = '0'
    'CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING'       = '1'
    'CLAUDE_CODE_DISABLE_INTERLEAVED_THINKING'    = '1'
    'CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY'  = '1'
    'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'        = '1'
    'CLAUDE_CODE_SUBAGENT_MODEL'                  = 'glm-5-turbo'
    'CLAUDE_CODE_USE_POWERSHELL_TOOL'             = '1'
    'ENABLE_LSP_TOOL'                             = '1'
    'BASH_MAX_TIMEOUT_MS'                         = '600000'
    'BASH_DEFAULT_TIMEOUT_MS'                     = '300000'
    'BASH_MAX_OUTPUT_LENGTH'                      = '20000'
    'API_TIMEOUT_MS'                              = '3000000'
    'MCP_TIMEOUT'                                 = '60000'
    'DISABLE_AUTO_COMPACT'                        = '0'
    'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE'             = '80'
    'LC_ALL'                                      = 'en_US.UTF-8'
    'PYTHONIOENCODING'                            = 'utf-8'
    'PYTHONUTF8'                                  = '1'
    'CLAUDE_CODE_GIT_BASH_PATH'                   = 'D:\ohmyenv\git\bin\bash.exe'
}
foreach ($entry in $envVars.GetEnumerator()) {
    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'User')
    Set-Item "env:$($entry.Key)" $entry.Value
}
Write-Host "[OK] 用户环境变量已设置（$($envVars.Count) 项，含 ANTHROPIC_BASE_URL / 遥测关闭）" -ForegroundColor Green

# ── 4. settings.json env 块幂等合并（GLM-5.3 1M 上下文） ──
$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
$configDir = Split-Path $settingsPath -Parent
New-Item -ItemType Directory -Path $configDir -Force | Out-Null

$envBlock = [ordered]@{
    'CLAUDE_CODE_AUTO_COMPACT_WINDOW' = '1000000'
    'ANTHROPIC_DEFAULT_HAIKU_MODEL'   = 'glm-4.7'
    'ANTHROPIC_DEFAULT_SONNET_MODEL'  = 'glm-5.3[1m]'
    'ANTHROPIC_DEFAULT_OPUS_MODEL'    = 'glm-5.3[1m]'
}

if (Test-Path -LiteralPath $settingsPath) {
    $settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
} else {
    $settings = [pscustomobject]@{}
}
$obj = [ordered]@{}
$settings.PSObject.Properties | ForEach-Object { $obj[$_.Name] = $_.Value }
if (-not $obj.Contains('env')) { $obj['env'] = [ordered]@{} }
$envTarget = $obj['env']
if ($envTarget -isnot [System.Collections.IDictionary]) {
    $envTarget = [ordered]@{}
    $obj['env'] = $envTarget
}
foreach ($entry in $envBlock.GetEnumerator()) {
    $envTarget[$entry.Key] = $entry.Value
}
$json = $obj | ConvertTo-Json -Depth 12
if (Test-Path -LiteralPath $settingsPath) {
    $old = (Get-Content -Raw -LiteralPath $settingsPath).Trim()
    if ($old -eq $json.Trim()) {
        Write-Host '[INFO] settings.json 已是最新，跳过' -ForegroundColor DarkGray
        exit 0
    }
    Copy-Item -LiteralPath $settingsPath -Destination "$settingsPath.bak-$(Get-Date -Format 'yyyyMMddHHmmss')" -Force
}
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Host "[OK] 已写入: $settingsPath" -ForegroundColor Green
