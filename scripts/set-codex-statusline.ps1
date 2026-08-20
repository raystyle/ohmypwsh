#Requires -Version 7.0
# set-codex-statusline.ps1 - Codex 安装后增强配置：TUI 状态栏（幂等合并，不覆盖现有配置）
# 功能：合并 [tui] status_line 到 %USERPROFILE%\.codex\config.toml，保留 DeepSeek/沙箱/信任项目等既有配置。
# 用法: pwsh -NoProfile -File scripts\set-codex-statusline.ps1
#       可选: -StatusLine @('model-with-reasoning','git-branch','context-remaining')  -NoColors

param(
    [string[]]$StatusLine = @(
        'model-with-reasoning',
        'context-used',
        'context-window-size',
        'current-dir',
        'git-branch',
        'branch-changes'
    ),
    [switch]$NoColors
)

$ErrorActionPreference = 'Stop'

$configDir  = Join-Path $env:USERPROFILE '.codex'
$configPath = Join-Path $configDir 'config.toml'
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
if (-not (Test-Path -LiteralPath $configPath)) {
    Set-Content -LiteralPath $configPath -Value '' -Encoding utf8
}

$lines = @(Get-Content -LiteralPath $configPath)

# 1) 移除已有 [tui] 顶层段（到下一个顶层表为止），整段替换实现幂等
$out = [System.Collections.Generic.List[string]]::new()
$inTui = $false
foreach ($ln in $lines) {
    if ($ln -match '^\[\s*tui\s*\]\s*$') { $inTui = $true; continue }
    if ($inTui) {
        if ($ln -match '^\s*\[') { $inTui = $false } else { continue }
    }
    $out.Add($ln)
}

# 2) 组装新的 [tui] 段
$block = [System.Collections.Generic.List[string]]::new()
$block.Add('[tui]')
$block.Add('status_line = [')
foreach ($item in $StatusLine) {
    if ($item -match '^[a-z0-9-]+$') { $block.Add('  "' + $item + '",') }
}
$block.Add(']')
if (-not $NoColors) { $block.Add('status_line_use_colors = true') }

# 3) 插到第一个顶层表之前（保持标量键在前、表在后，避免 TOML 解析冲突）
$insertAt = -1
for ($i = 0; $i -lt $out.Count; $i++) {
    if ($out[$i] -match '^\s*\[') { $insertAt = $i; break }
}
if ($insertAt -lt 0) { $out.AddRange($block) } else { $out.InsertRange($insertAt, $block) }

# 4) 编辑器 schema 提示行（官方 config 参考推荐，自动补全用）
if ($out.Count -eq 0 -or $out[0] -notmatch '^#:schema') {
    $out.Insert(0, '#:schema https://developers.openai.com/codex/config-schema.json')
}

Set-Content -LiteralPath $configPath -Value $out -Encoding utf8

Write-Host "[OK] 已合并 [tui] 状态栏配置: $configPath" -ForegroundColor Green
Write-Host "  status_line : $($StatusLine -join ', ')"
Write-Host "  colors      : $(-not $NoColors)"
Write-Host '[HINT] 重启 codex 新会话生效；TUI 内可 /statusline 交互微调顺序。' -ForegroundColor DarkGray
