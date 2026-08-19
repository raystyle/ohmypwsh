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

# ── 3. 用户级环境变量：只保留 API 端点（密钥归 set-claude-key.ps1；其余 claude 配置全部收敛进 settings.json env） ──
[Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', 'https://open.bigmodel.cn/api/anthropic', 'User')
Set-Item Env:ANTHROPIC_BASE_URL 'https://open.bigmodel.cn/api/anthropic'
Write-Host '[OK] 用户环境变量仅保留 ANTHROPIC_BASE_URL（其余 claude 配置收敛进 settings.json env）' -ForegroundColor Green

# ── 3.5 删除 omc 遗留/已收敛环境变量（含空串残留；必须用 [NullString]::Value 才真正删除） ──
$legacyEnv = @(
    'ANTHROPIC_AUTH_TOKEN',                  # omc 旧凭证变量
    'ANTHROPIC_DEFAULT_HAIKU_MODEL',         # omc GLM profile 旧值 glm-5-turbo
    'ANTHROPIC_DEFAULT_SONNET_MODEL',        # omc GLM profile 旧值 glm-5.2[1m]
    'ANTHROPIC_DEFAULT_OPUS_MODEL',          # omc GLM profile 旧值 glm-5.2[1m]
    'DISABLE_TELEMETRY',                     # 以下 24 项已收敛进 settings.json env
    'DISABLE_FEEDBACK_SURVEY',
    'DISABLE_AUTOUPDATER',
    'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
    'CLAUDE_CODE_DISABLE_1M_CONTEXT',
    'CLAUDE_CODE_ATTRIBUTION_HEADER',
    'CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING',
    'CLAUDE_CODE_DISABLE_INTERLEAVED_THINKING',
    'CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY',
    'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS',
    'CLAUDE_CODE_SUBAGENT_MODEL',
    'CLAUDE_CODE_USE_POWERSHELL_TOOL',
    'ENABLE_LSP_TOOL',
    'BASH_MAX_TIMEOUT_MS',
    'BASH_DEFAULT_TIMEOUT_MS',
    'BASH_MAX_OUTPUT_LENGTH',
    'API_TIMEOUT_MS',
    'MCP_TIMEOUT',
    'DISABLE_AUTO_COMPACT',
    'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE',
    'LC_ALL',
    'PYTHONIOENCODING',
    'PYTHONUTF8',
    'CLAUDE_CODE_GIT_BASH_PATH',
    'LANG',                                  # omc claude 优化集带出的 locale 变量
    'BUN_INSTALL',                           # omc bun 残留
    'BUN_INSTALL_CACHE_DIR',
    'BUN_RUNTIME_TRANSPILER_CACHE_PATH',
    'CARGO_HOME',                            # omc rust 残留
    'RUSTUP_HOME',
    'RUSTUP_DIST_SERVER',
    'RUSTUP_UPDATE_ROOT'
)
foreach ($legacyName in $legacyEnv) {
    $legacyVal = [Environment]::GetEnvironmentVariable($legacyName, 'User')
    if ($null -ne $legacyVal) {
        [Environment]::SetEnvironmentVariable($legacyName, [NullString]::Value, 'User')
        Remove-Item "Env:$legacyName" -ErrorAction SilentlyContinue
        Write-Host "[OK] 已删除旧环境变量 $legacyName（omc 遗留）" -ForegroundColor Green
    } else {
        Write-Host "[INFO] $legacyName 未设置（已是干净状态）" -ForegroundColor DarkGray
    }
}

# ── 4. settings.json 幂等合并（env 块 + 完整 YOLO + 删除 omc 遗留键） ──
$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
$configDir = Split-Path $settingsPath -Parent
New-Item -ItemType Directory -Path $configDir -Force | Out-Null

$envBlock = [ordered]@{
    # ── GLM-5.3 1M 上下文（用户指定） ──
    'CLAUDE_CODE_AUTO_COMPACT_WINDOW'        = '1000000'
    'ANTHROPIC_DEFAULT_HAIKU_MODEL'          = 'glm-4.7'
    'ANTHROPIC_DEFAULT_SONNET_MODEL'         = 'glm-5.3[1m]'
    'ANTHROPIC_DEFAULT_OPUS_MODEL'           = 'glm-5.3[1m]'
    # ── 优化集（原 omc 用户级变量，收敛至此；不装插件/hook，关遥测） ──
    'DISABLE_TELEMETRY'                      = '1'
    'DISABLE_FEEDBACK_SURVEY'                = '1'
    'DISABLE_AUTOUPDATER'                    = '1'
    'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC' = '1'
    'CLAUDE_CODE_DISABLE_1M_CONTEXT'         = '0'
    'CLAUDE_CODE_ATTRIBUTION_HEADER'         = '0'
    'CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING'  = '1'
    'CLAUDE_CODE_DISABLE_INTERLEAVED_THINKING' = '1'
    'CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY' = '1'
    'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'   = '1'
    'CLAUDE_CODE_SUBAGENT_MODEL'             = 'glm-5-turbo'
    'CLAUDE_CODE_USE_POWERSHELL_TOOL'        = '1'
    'ENABLE_LSP_TOOL'                        = '1'
    'BASH_MAX_TIMEOUT_MS'                    = '600000'
    'BASH_DEFAULT_TIMEOUT_MS'                = '300000'
    'BASH_MAX_OUTPUT_LENGTH'                 = '20000'
    'API_TIMEOUT_MS'                         = '3000000'
    'MCP_TIMEOUT'                            = '60000'
    'DISABLE_AUTO_COMPACT'                   = '0'
    'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE'        = '80'
    'LC_ALL'                                 = 'en_US.UTF-8'
    'LANG'                                   = 'en_US.UTF-8'
    'PYTHONIOENCODING'                       = 'utf-8'
    'PYTHONUTF8'                             = '1'
    'CLAUDE_CODE_GIT_BASH_PATH'              = 'D:\ohmyenv\git\bin\bash.exe'
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

# 4.1 删除 omc 遗留 settings 键（思考开关/effort 由 claude /effort 命令管理，默认 max）
foreach ($legacyKey in @('alwaysThinkingEnabled', 'effortLevel')) {
    if ($obj.Contains($legacyKey)) {
        $obj.Remove($legacyKey)
        Write-Host "[OK] 已删除旧 settings 键: $legacyKey（omc 遗留）" -ForegroundColor Green
    }
}

# 4.2 permissions → 完整 YOLO（对齐 Codex danger-full-access + approval_policy=never：
#      默认 bypassPermissions，Shift+Tab 可临时切回逐次确认；旧 allow/deny 规则删除）
#      注意：disableBypassPermissionsMode 必须是字符串 "disable"（本版枚举仅此一值），
#      写布尔 false 会让整个 settings.json 解析失败被跳过 → 不写该键（默认不禁止切换）。
$obj['permissions'] = [ordered]@{
    defaultMode = 'bypassPermissions'
}
Write-Host '[OK] permissions 已设为完整 YOLO（默认 bypassPermissions，不禁用切换）' -ForegroundColor Green

# ── 4.3 PATH / PSModulePath 清理（omc 残留；幂等） ──
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath) {
    $keepPath = ($userPath -split ';') | Where-Object { $_ -and $_ -notmatch '(?i)^D:\\Oh-My-Claude(\\|$)' -and $_ -notmatch '(?i)^C:\\Users\\ray\\.local\\bin$' }
    $newPath = ($keepPath -join ';')
    if ($newPath -ne $userPath) {
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + $newPath
        Write-Host '[OK] 用户 PATH 已移除 omc 残留（D:\Oh-My-Claude\* 与 .local\bin）' -ForegroundColor Green
    } else {
        Write-Host '[INFO] 用户 PATH 无 omc 残留' -ForegroundColor DarkGray
    }
}
$psmp = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
if ($psmp) {
    $deadPsmp = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Modules'
    $keepPsmp = ($psmp -split ';') | Where-Object { $_ -and $_ -ne $deadPsmp }
    $newPsmp = ($keepPsmp -join ';')
    if ($newPsmp -ne $psmp) {
        [Environment]::SetEnvironmentVariable('PSModulePath', $newPsmp, 'User')
        Write-Host '[OK] PSModulePath 已移除死路径（Documents\WindowsPowerShell\Modules）' -ForegroundColor Green
    } else {
        Write-Host '[INFO] PSModulePath 无死路径' -ForegroundColor DarkGray
    }
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
