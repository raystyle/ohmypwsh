# Agent 密钥泄露防护（统一 Secret Guard）

四个 CLI 的密钥/凭证泄露拦截方案，共用同一份 `scripts\hooks\secret-guard.py`，由
`scripts\set-agent-secret-guard.ps1` 幂等部署到四个工具。所有字段名、配置路径与阻断语义均
按官方文档/本地实测核实，避免贴错格式导致 hook 静默失效。

## 结论速览

| CLI | 配置文件 | hooks 结构 | 匹配字段 | timeout 单位 | 阻断方式 |
| --- | --- | --- | --- | --- | --- |
| Claude Code | `~/.claude/settings.json` | JSON `hooks` | `matcher` | 秒 | exit 2 |
| Codex CLI | `~/.codex/hooks.json` + `config.toml` `[features] hooks=true` | JSON `hooks` | `matcher` | 秒 | exit 2 + `hookSpecificOutput` |
| Kimi Code CLI | `~/.kimi-code/config.toml` | TOML `[[hooks]]` | `matcher`（可省略=全部） | 秒 | exit 2 |
| Reasonix | `%APPDATA%\reasonix\settings.json` | JSON `hooks` | `match`（注意单数） | 毫秒 | exit 2 |

统一脚本按 stdin JSON 的「信封」自动识别格式，无需为每个 CLI 维护多份脚本：

- `event` 字段存在 → **Reasonix**（camelCase）
- `hook_event_name` 字段存在 → **Claude Code / Kimi Code**（两者都是 Claude 形状，snake_case）
- 其余 → **Codex CLI**（snake_case，无 `hook_event_name`，靠 payload 推断事件）

## 各 CLI hook 格式（核实结论）

### Claude Code

- 配置：`~/.claude/settings.json` 的 `hooks`，`matcher` + `hooks[]`（`type`/`command`/`timeout`/`statusMessage`）。
- stdin JSON 含 `hook_event_name`、`tool_name`/`tool_input`/`tool_response`/`prompt`（snake_case）。
- 事件同时经环境变量 `CLAUDE_HOOK_EVENT` 注入。
- `PreToolUse` / `UserPromptSubmit` 可阻断（exit 2）；`PostToolUse` 仅告警。
- timeout 单位：秒。

### Codex CLI

- 配置：`~/.codex/hooks.json`（`hooks` → 事件数组，结构与 Claude 一致），特性开关是
  `~/.codex/config.toml` 的 `[features] hooks = true`。
- 注意：不是 `codex_hooks = true`（旧版/其它资料写法，当前版本实测为 `hooks = true`）。
- stdin JSON 为 snake_case，但**不包含** `hook_event_name`；脚本用 `tool_response`/`output`/
  `tool_name`/`prompt` 推断事件。
- `PreToolUse` / `UserPromptSubmit` 阻断需要同时输出 `hookSpecificOutput.permissionDecision=deny`
  与 exit 2；`PostToolUse` 用 stdout JSON `{output, secret_scan_blocked}` 替换输出。

### Kimi Code CLI

- 配置：`~/.kimi-code/config.toml` 的 `[[hooks]]` 数组，仅允许 `event`/`matcher`/`command`/
  `timeout` 四个字段，多写会解析失败。
- stdin JSON 与 Claude 同形（`hook_event_name` + snake_case）。
- 可阻断事件：`PreToolUse`、`Stop`、`UserPromptSubmit`；`PostToolUse` 为观察型。
- timeout 单位：秒（1–600，默认 30）。
- `matcher` 省略即匹配全部；`command` 用 TOML 字面量字符串 `'...'` 写 Windows 路径，避免反斜杠转义。

### Reasonix

- 配置：Windows 为 `%APPDATA%\reasonix\settings.json`（macOS/Linux 为 `~/.reasonix/settings.json`），
  `hooks` → 事件数组，字段是 `match`（**不是** `matcher`）/`command`/`timeout`/`cwd`/`description`。
- 11 个事件，仅 `PreToolUse`、`UserPromptSubmit` 可阻断（exit 2）；`PostToolUse` 观察型。
- stdin JSON 含 `event`、`cwd`，工具字段为 camelCase：`toolName`/`toolArgs`；`PostToolUse`
  的结果字段是 `toolResult`（**不是** `toolResponse`/`toolOutput`）。
- timeout 单位：**毫秒**（阻塞事件默认 5000，其它默认 30000）。
- `match` 是锚定正则，`*` 或空字符串匹配所有工具；命令在 Windows 默认经 `cmd /c` 执行。
- 可用只读诊断：`reasonix hook status --json`、`reasonix doctor capabilities`。

## 实现要点 / 踩坑

- `detect_cli_format` 必须先判 `event`（Reasonix）再判 `hook_event_name`（Claude/Kimi），
  否则 Reasonix 的 `UserPromptSubmit`（无 toolName/toolArgs）会被误判成 Codex。
- Reasonix 的 shell 工具 `toolName` 是小写 `bash`，脚本对 `bash/shell/powershell/pwsh` 统一取
  `toolArgs.command`；`PostToolUse` 只认 `toolResult`。
- 环境变量真实值泄露检测要求 `len(value) >= 8`，避免 1–3 字符短值造成误报。
- 任何异常都 fail-open（exit 0），保证 guard 自身异常不会卡住 agent。
- hook 命令统一用 `python3`（Windows 由 `set-python-config.ps1` 建别名，WSL/Linux 原生
  `python3`），同一 `secret-guard.py` 可直接复用。
- 部署脚本按 `secret-guard.py` 定位并更新命令（upsert），重复运行不追加重复 hook，也能把旧
  绝对路径命令迁移为 `python3`。
- **改源码必须重部署**：每一处对 `scripts\hooks\secret-guard.py` 的修改，都必须重跑
  `pwsh -NoProfile -File scripts\set-agent-secret-guard.ps1`，把新副本推到四个 CLI 的 hooks 目录
  （`~/.claude/hooks`、`~/.codex/hooks`、`~/.kimi-code/hooks`、`%APPDATA%\reasonix\hooks`）。
  已部署副本是**复制**而非软链，重跑脚本前它们依旧是旧版——常见踩坑是「改了源码但各 agent
  仍跑旧 hook」，导致修复不生效或新旧行为不一（2026-08-21 实测：改了 guard_self_file 豁免后
  未重部署，Reasonix PostToolUse 仍用旧 hook 把测试命令里的 `AKIA...EXAMPLE` 误拦）。
  验证方式：比对各副本与源码的 sha256 是否一致。

## 测试

`scripts\hooks\_test_secret_guard.py` 用四类 payload（Claude/Kimi/Codex/Reasonix × 各类事件 +
干净样本）回归退出码与阻断/告警行为：

```powershell
pwsh -NoProfile -Command "& 'D:\ohmyenv\python\python.exe' 'D:\ohmypwsh\scripts\hooks\_test_secret_guard.py'"
```

## 参考来源

- Reasonix：`docs/DESKTOP_HOOKS.zh-CN.md`（esengine/DeepSeek-Reasonix）、`reasonix hook status --json`
- Kimi Code：https://www.kimi.com/code/docs/kimi-code-cli/customization/hooks.html
- Claude Code / Codex：本机 `~/.claude/settings.json`、`~/.codex/hooks.json`、`~/.codex/config.toml` 实测
