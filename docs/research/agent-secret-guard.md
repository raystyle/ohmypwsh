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
- hook 命令统一用 **python3 绝对路径**（`D:\ohmyenv\python\python3.exe`，不再用裸 `python3`）：
  WSL/Linux 侧仍用原生 `python3`。改绝对路径的原因是 Reasonix（桌面 GUI 程序）执行 hook 时
  用自己的子进程 PATH（可能是启动 Reasonix 那一刻继承的旧 PATH，不含 `D:\ohmyenv\python`），
  裸 `python3` 解析不到会直接导致 hook 失败、整个工具调用被判 `context canceled`；绝对路径
  消除这条 PATH 依赖（2026-08-21 实测）。
- 部署脚本按 `secret-guard.py` 定位并更新命令（upsert），重复运行不追加重复 hook，也能把旧
  `python3`/旧绝对路径命令统一迁移为当前 python3 绝对路径。
- **改源码必须重部署**：每一处对 `scripts\hooks\secret-guard.py` 的修改，都必须重跑
  `pwsh -NoProfile -File scripts\set-agent-secret-guard.ps1`，把新副本推到四个 CLI 的 hooks 目录
  （`~/.claude/hooks`、`~/.codex/hooks`、`~/.kimi-code/hooks`、`%APPDATA%\reasonix\hooks`）。
  已部署副本是**复制**而非软链，重跑脚本前它们依旧是旧版——常见踩坑是「改了源码但各 agent
  仍跑旧 hook」，导致修复不生效或新旧行为不一（2026-08-21 实测：改了 guard_self_file 豁免后
  未重部署，Reasonix PostToolUse 仍用旧 hook 把测试命令里的 `AKIA...EXAMPLE` 误拦）。
- **codex `hook exited with code 1` 是「进程启动失败」，不是 guard 判定**（2026-08-21 追加）：
  `secret-guard.py` 全部分支只有 exit 0 / exit 2（无 exit 1），所以 codex 报 exit 1 必是 hook
  命令本身没起来。根因：`set-agent-secret-guard.ps1` 生成的 codex command 带内嵌双引号
  （`"...python3.exe" "...secret-guard.py"`），codex 0.149.0 在 Windows 按 `cmd /C` 逐字执行 +
  argv 拆分时，引号字面量被带入导致启动失败。修复方式：codex 键**去引号**（`D:\ohmyenv\python\python3.exe
  C:\Users\ray\.codex\hooks\secret-guard.py`，两路径均无空格），Claude Code / Reasonix 因各自
  CLI 需要引号包裹 Windows 路径而保持不变。判据口诀：**报错的 exit code 不在 guard 的
  exit code 集合（{0,2}）里，先怀疑命令执行层而非脚本逻辑**。
  验证方式：比对各副本与源码的 sha256 是否一致。
- **codex Windows 的 hook stdin 是 UTF-16（可带/不带 BOM）**：`json.loads(sys.stdin.read())`
  按 UTF-8 读会得到错位字符，报 `Expecting ',' delimiter: line 1 column N`，导致 fail-open
  且 codex 显示 `PostToolUse hook (failed): hook exited with code 1`（2026-08-21 实测，日志
  `verdict=error` 两条即此因）。修复 = **编码自愈**：读 raw bytes → BOM 精确优先
  （utf-8-sig / utf-16-le / utf-16-be）→ 无 BOM 按精简一级备选（utf-8 → utf-16-le →
  utf-16-be → gbk）严格解码 + `json.loads` 逐个试探，成功即用，全部失败才 fail-open。不要用
  `errors=replace`（会静默吞字节导致漏扫），也不要引入 `latin-1`（解码永不失败、掩盖真实错误，
  纯浪费候选）。自愈后 UTF-8 / UTF-16LE 无 BOM / UTF-16LE 带 BOM 三种输入均实测
  `cli=codex PostToolUse pass`，且密钥命中仍正常 block。

## 日志（排查误报/执行情况）`secret-guard.py` 每次执行写一行 JSON 日志（2026-08-21 新增），用于事后排查「误报 / 漏报 /
hook 执行失败」：

- 路径：`SECRET_GUARD_LOG` 环境变量 > 平台默认（Windows `%LOCALAPPDATA%\ohmyenv\secret-guard.log`，
  Linux `~/.local/state/ohmyenv/secret-guard.log`）；设 `SECRET_GUARD_LOG=off` 关闭。
- 每条记录字段：`ts` / `verdict`（`pass`·`block`·`warn`·`error`）/ `cli` / `event` / `text_len` /
  `hits`（命中类型数组，**只记类型不记明文**）/ 可选 `error`。
- 语义：`pass` = 未命中；`block` = PreToolUse/UserPromptSubmit 命中被阻断（exit 2）；
  `warn` = PostToolUse 命中仅告警；`error` = guard 自身异常（fail-open，exit 0）。
- 日志写盘异常静默忽略，绝不反噬 hook 判定；日志内容不含被扫描文本与密钥明文。

排查看法：
```powershell
# Windows 默认日志（每行一条 JSON）
Get-Content "$env:LOCALAPPDATA\ohmyenv\secret-guard.log" -Tail 50
# 只看阻断/告警/错误
... | Where-Object { $_ -match '"verdict": "(block|warn|error)"' }
```

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
