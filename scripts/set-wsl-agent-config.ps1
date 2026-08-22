#Requires -Version 7.0
# set-wsl-agent-config.ps1 - 三 agent 配置平移：Codex / Claude Code / Kimi（Linux 专属幂等配置）
# 不拷贝 Windows 文件（值/路径与 Linux 不同），在 WSL 内生成 Linux 语义配置：
#   ~/.codex/config.toml        DeepSeek 模型/沙箱/env_key + Linux 状态栏 + 信任 $HOME（无 [windows] 段）
#   ~/.claude/settings.json     GLM-5.3[1m] 三档模型 + 1M 窗口 + YOLO 权限 + 关遥测（剔除 Windows 专属键）
#   ~/.claude.json              onboarding 修复 + 工作区信任（对齐 Windows 语义）
#   ~/.kimi-code/config.toml    kimi-code/k3 + 权限模式 + telemetry=false
# 用法: pwsh -NoProfile -File scripts\set-wsl-agent-config.ps1 [-Distro ohmywsl] [-User ray] [-KimiPermissionMode auto]
# 前置: ohmywsl distro 已导入；API Key 由 set-wsl-keys.ps1 提供（agent 二进制本身本轮不安装）。

param(
    [string]$Distro = 'ohmywsl',
    [string]$User = 'ray',
    [ValidateSet('auto', 'yolo', 'manual')][string]$KimiPermissionMode = 'auto'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'helpers.ps1')

$envRoot = Get-DefaultEnvRoot
$stageDir = Join-Path $envRoot 'cache\wsl-agent-config'
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

function ConvertTo-WslPath {
    param([Parameter(Mandatory)][string]$WinPath)
    $drive = $WinPath.Substring(0, 1).ToLower()
    return '/mnt/' + $drive + $WinPath.Substring(2).Replace('\', '/')
}

function Invoke-UW {
    param([Parameter(Mandatory)][string]$Command)
    $prev = [Console]::OutputEncoding
    [Console]::OutputEncoding = [System.Text.Encoding]::Unicode
    try {
        & wsl -d $Distro -u $User -e bash -lc $Command
        return $LASTEXITCODE
    } finally {
        [Console]::OutputEncoding = $prev
    }
}

$prevEnc = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode
$hasDistro = [bool]((wsl -l -q 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $Distro }))
[Console]::OutputEncoding = $prevEnc
if (-not $hasDistro) { throw "WSL distro $Distro 不存在，先导入: scripts\set-wsl-distro.ps1" }

# ── 1. ~/.codex/config.toml（Linux 语义：去 [windows]、去 Windows hook state/绝对 Windows 路径）──
$codexToml = @'
#:schema https://developers.openai.com/codex/config-schema.json
sandbox_mode = "danger-full-access"
approval_policy = "never"
model = "deepseek-v4-pro"
model_provider = "deepseek"
preferred_auth_method = "apikey"
forced_login_method = "api"
model_reasoning_effort = "high"

[tui]
status_line = [
  "model-with-reasoning",
  "context-used",
  "context-window-size",
  "current-dir",
  "git-branch",
  "branch-changes",
]
status_line_use_colors = true

[model_providers.deepseek]
name = "deepseek"
base_url = "https://api.deepseek.com/"
wire_api = "responses"
env_key = "DEEPSEEK_API_KEY"

[projects.'/home/ray']
trust_level = "trusted"

[features]
hooks = true
'@
$codexStage = Join-Path $stageDir 'codex-config.toml'
[System.IO.File]::WriteAllText($codexStage, $codexToml, (New-Object System.Text.UTF8Encoding $false))
$null = Invoke-UW -Command "mkdir -p `$HOME/.codex && cp '$(ConvertTo-WslPath $codexStage)' `$HOME/.codex/config.toml && echo codex-config-ok"
if ($LASTEXITCODE -ne 0) { throw '写入 ~/.codex/config.toml 失败' }
Write-Host '[OK] ~/.codex/config.toml：DeepSeek 模型 + Linux 状态栏 + 信任 /home/ray（无 [windows] 段）' -ForegroundColor Green

# ── 2. ~/.claude/settings.json（剔除 Windows 专属键：CLAUDE_CODE_GIT_BASH_PATH /
#       CLAUDE_CODE_USE_POWERSHELL_TOOL / DISABLE_INSTALLATION_CHECKS）──
$claudeSettings = [ordered]@{
    env = [ordered]@{
        'ANTHROPIC_BASE_URL'                     = 'https://open.bigmodel.cn/api/anthropic'
        'CLAUDE_CODE_AUTO_COMPACT_WINDOW'        = '1000000'
        'ANTHROPIC_DEFAULT_HAIKU_MODEL'          = 'glm-4.7'
        'ANTHROPIC_DEFAULT_SONNET_MODEL'         = 'glm-5.3[1m]'
        'ANTHROPIC_DEFAULT_OPUS_MODEL'           = 'glm-5.3[1m]'
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
    }
    permissions = [ordered]@{ defaultMode = 'bypassPermissions' }
}
$claudeStage = Join-Path $stageDir 'claude-settings.json'
[System.IO.File]::WriteAllText($claudeStage, ($claudeSettings | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding $false))
$null = Invoke-UW -Command "mkdir -p `$HOME/.claude && cp '$(ConvertTo-WslPath $claudeStage)' `$HOME/.claude/settings.json && echo claude-settings-ok"
if ($LASTEXITCODE -ne 0) { throw '写入 ~/.claude/settings.json 失败' }
Write-Host '[OK] ~/.claude/settings.json：GLM-5.3[1m] 1M 窗口 + YOLO + 关遥测（无 Windows 专属键）' -ForegroundColor Green

# ── 3. ~/.claude.json（onboarding 修复：跳过登录验证；工作区信任主工作区）──
$claudeJson = [ordered]@{
    hasCompletedOnboarding = $true
    projects = [ordered]@{}
}
$claudeJson['projects']['/mnt/d/ohmypwsh'] = [ordered]@{
    hasTrustDialogAccepted      = $true
    hasTrustDialogHooksAccepted = $true
}
$claudeJsonStage = Join-Path $stageDir 'claude.json'
[System.IO.File]::WriteAllText($claudeJsonStage, ($claudeJson | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))
$null = Invoke-UW -Command "cp '$(ConvertTo-WslPath $claudeJsonStage)' `$HOME/.claude.json && echo claude-json-ok"
if ($LASTEXITCODE -ne 0) { throw '写入 ~/.claude.json 失败' }
Write-Host '[OK] ~/.claude.json：onboarding 跳过 + 工作区信任（/mnt/d/ohmypwsh）' -ForegroundColor Green

# ── 4. ~/.kimi-code/config.toml ──
$kimiToml = @"
default_model = "kimi-code/k3"
default_permission_mode = "$KimiPermissionMode"
telemetry = false
"@
$kimiStage = Join-Path $stageDir 'kimi-config.toml'
[System.IO.File]::WriteAllText($kimiStage, $kimiToml, (New-Object System.Text.UTF8Encoding $false))
$null = Invoke-UW -Command "mkdir -p `$HOME/.kimi-code && cp '$(ConvertTo-WslPath $kimiStage)' `$HOME/.kimi-code/config.toml && echo kimi-config-ok"
if ($LASTEXITCODE -ne 0) { throw '写入 ~/.kimi-code/config.toml 失败' }
Write-Host "[OK] ~/.kimi-code/config.toml：default_model=kimi-code/k3, permission=$KimiPermissionMode, telemetry=false" -ForegroundColor Green

# ── 5. 校验（不依赖 agent 二进制，只校验配置文件存在 + parse）──
$null = Invoke-UW -Command "test -f `$HOME/.codex/config.toml && test -f `$HOME/.claude/settings.json && test -f `$HOME/.claude.json && test -f `$HOME/.kimi-code/config.toml && echo ALL-FILES-OK"
if ($LASTEXITCODE -ne 0) { throw '配置文件缺失校验失败' }
$null = Invoke-UW -Command "jq empty `$HOME/.claude/settings.json && jq empty `$HOME/.claude.json && echo JSON-PARSE-OK"
if ($LASTEXITCODE -ne 0) { throw 'JSON parse 校验失败' }
Write-Host '[OK] 三 agent 配置全部落位且 JSON/文件校验通过' -ForegroundColor Green
Write-Host '[HINT] agent 二进制不进基础镜像、本轮不装；装好 codex/claude/kimi 后直接复用本配置。' -ForegroundColor DarkGray
