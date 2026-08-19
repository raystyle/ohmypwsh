---
name: rmux
description: 由 Codex 或 Claude Code 开一个新终端窗口，用 RMUX（Windows/pwsh）在同一个终端的不同窗格里分别运行并操作多个 agent（codex / claude）：新终端 + rmux 多窗格流程、send-keys/capture-pane 驱动、环境清理（NO_COLOR/TERM/PATH）、关闭退出。涉及 rmux/tmux、分屏或驱动调试 claude/codex 时使用。
---

# RMUX：新终端 + 同终端多窗格多 agent 操作

用途：作为 agent（Codex 或 Claude Code）开一个新终端窗口，用 rmux 把多个 agent（如 codex、
claude）放到同一个终端的不同窗格里，再通过 rmux 命令分别驱动。rmux 本体已在 PATH
（`rmux` 命令直接可用），wt 用 `Get-Command` 动态解析，**不要硬编码安装路径**。

## 核心流程：新开终端 + rmux 同终端多窗格

```powershell
# 0. 环境准备（关键，缺一不可）：
#    - 当前环境若带 NO_COLOR=1（Codex exec 沙箱必有），必须 Remove-Item，否则 agent 无色彩
#    - TERM=dumb 会让 rmux 客户端无色彩 → 设 xterm-256color
#    - PATH 按注册表重建（含 .local\bin），否则 claude /status 报 native 安装警告；
#      注意：重建会丢弃进程级临时 PATH 追加项，工具路径以注册表为准
# 0.1 旧 daemon 守卫：daemon 若由污染环境（含 NO_COLOR）启动，新窗格颜色仍会坏；
#     无保留会话时先 kill-server，让下面步骤用干净环境重启 daemon
if (Get-Process rmux -ErrorAction SilentlyContinue) {
    $left = rmux list-sessions 2>$null
    if (-not $left) { rmux kill-server }
}
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'
$env:COLORTERM = 'truecolor'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# 1. 会话复用守卫：dev 已存在先杀掉，避免 new-session 报错后 split 追加出 dev:0.2，
#    破坏固定的 dev:0.0/dev:0.1 窗格索引
if (rmux has-session -t dev 2>$null) { rmux kill-session -t dev }

# 2. 建会话并分窗格：窗格 0 = codex，窗格 1 = claude（右侧；-d 新窗格不抢焦点）。
#    显式 -c：wt 新窗口默认 cwd 是 %USERPROFILE%，不继承调用方目录，必须指定工作目录
$wd = (Get-Location).Path
rmux new-session -d -s dev -c $wd 'codex'
rmux split-window -h -d -t dev -c $wd 'claude'

# 3. 弹新终端窗口 attach（-w new 强制新窗口；-d 指定目录；Minimized 最小化启动不抢主窗口焦点）
$wt = (Get-Command wt.exe).Source
$wtArgs = "-w new --title `"Codex + Claude`" -d `"$wd`" pwsh -NoProfile -Command `"rmux attach-session -t dev`""
Start-Process -FilePath $wt -ArgumentList $wtArgs -WindowStyle Minimized

# 4. 等待窗口 attach（wt 启动 + pwsh + attach 约 1-2s），再检查/操作，避免竞态
Start-Sleep -Seconds 2
rmux list-clients          # [宽x高 term]：dumb=无色彩；detach-client -t <id> 重开
rmux send-keys -t dev:0.1 --wait quiet --stable-for 800ms --timeout 15s -- '/status' Enter
# codex/claude 是全屏 TUI（alternate screen），ConPTY 下 capture-pane 返回空——
# 验证改用 list-clients 的 term 标记、非 TUI 命令输出（claude -p）、stream-pane 或让用户目视
```

## 单 agent 变体：新窗口只开 claude（或 codex）

同构，仅命令与会话名不同；`new-session -A` 在会话已存在时直接 attach：

```powershell
if (Get-Process rmux -ErrorAction SilentlyContinue) {
    $left = rmux list-sessions 2>$null
    if (-not $left) { rmux kill-server }
}
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'; $env:COLORTERM = 'truecolor'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$wd = (Get-Location).Path
$wt = (Get-Command wt.exe).Source
$wtArgs = "-w new --title `"Claude Code`" -d `"$wd`" pwsh -NoProfile -Command `"rmux new-session -A -s claude -c `"$wd`" claude`""
Start-Process -FilePath $wt -ArgumentList $wtArgs -WindowStyle Minimized
Start-Sleep -Seconds 2
rmux list-clients
```

## 会话 / 窗格基础（tmux 兼容）

```powershell
rmux new-session -d -s NAME -c <dir> 'cmd'   # 后台新会话（-c 显式指定工作目录）
rmux list-sessions                            # 会话列表
rmux has-session -t NAME                      # 会话是否存在（复用守卫）
rmux attach-session -t NAME                   # 附加
rmux split-window -h -d -t NAME -c <dir> 'cmd' # 右侧分割（-v 上下；-d 不抢焦点）
rmux list-panes -t NAME                       # 窗格列表
rmux kill-session -t NAME                     # 关闭会话
rmux find-sessions / rmux find-panes          # 查找（含 pane id）
```

## send-keys：目标、`--` 分隔与提交原语

- `-t` 三种写法：会话名（`-t dev`）、`session:window.pane`（`-t dev:0.1`）、pane id（`-t %3`）
- 内容放 `--` 之后；键名 `Enter` / `Down` / `Up` / `C-c`
- **提交原语：发送后必须验证已提交**——capture 输入行清空或出现处理指示（Pollinating / Thought），
  仍在输入行就补发 `Enter`；长 prompt 建议「发文本 → 检查 → Enter」分步，避免吞键
- **中文 payload 会丢失/乱码**（实测产生 `server closed connection`）：驱动 prompt 用 ASCII/英文，或走 `claude -p` 管道传中文
- **tiny CLI 误报「can't find pane」**：Windows 包 = `rmux.exe`（tiny 分发器）+
  `libexec\rmux\rmux.exe`（full helper），设 `RMUX_DISABLE_TINY_CLI=1` 强制走 full helper 重试
- `--wait` 本版本只支持 `quiet`；`--wait-next-text` / `--wait-text` / `--wait-visible-text` 是独立参数

```powershell
rmux send-keys -t dev -- 'echo hi' Enter
rmux send-keys -t dev --wait quiet --stable-for 500ms --timeout 2m -- 'cargo test' Enter
```

等待语义（**避免盲 sleep，必配 `--timeout`**）：

- `--wait quiet`：等输出静默（构建/测试/未知结束文本的默认选择）
- `--wait-next-text TEXT` / `--wait-text TEXT`：等指定文本出现
- `--wait-visible-text TEXT`：等渲染可见文本
- `--wait-pane-exit`：一次性进程（预期退出）

## 读取输出

```powershell
rmux capture-pane -t dev -p              # 全量文本
rmux pane-snapshot -t dev                # 快照
rmux stream-pane -t dev --lines          # 增量输出
rmux wait-pane -t dev --quiet --timeout 30s
```

**TUI 限制（重要）**：codex/claude 等全屏 TUI 走 alternate screen，Windows ConPTY 下
`capture-pane` / `pane-snapshot` 返回空。验证改用：`list-clients` 的 term 标记、
非 TUI 命令输出（`claude -p`、普通命令）、`stream-pane`，或让用户目视窗格。

## 关闭 / 退出（前缀键 Ctrl+B，与 tmux 一致）

- 只离开不杀会话：`Ctrl+B d`（detach），会话保留可再 attach
- 关当前会话/窗格：窗格内 `exit`；`Ctrl+B x` 杀窗格（y 确认）、`Ctrl+B &` 杀窗口、`Ctrl+B :` 命令模式 `kill-session`
- 彻底关闭：`rmux kill-server`（杀 daemon 及全部会话/窗格）；验证 `Get-Process rmux` 为空
- daemon 在最后一个会话被杀后自动退出（实测）；kill-server 会终止所有窗格里的 agent

## 详细踩坑

完整实测记录（daemon 进程模型、NO_COLOR 根源、ConPTY 备屏限制、关闭退出验证等）见
`docs\research\rmux-usage.md`，双端 skill 与该文档同步维护。
