# RMUX 正确用法研究（gh 调研 + 本机实测）

> 2026-08-19，来源：Helvesec/rmux v0.10.0（README、docs/integrations/claude-code.md、docs/man/rmux.1、resources/claude/skills/rmux/SKILL.md）+ 本机 Windows 10 实测。

## 结论

- RMUX 是 Rust 写的 tmux 兼容终端复用器（105 个命令），Windows 原生 ConPTY，无需 WSL
- 本机部署：`D:\ohmyenv\rmux`（ohmyenv 管理，已前置 PATH）。Windows 包 = `rmux.exe`（tiny CLI 分发器）+ `libexec\rmux\rmux.exe`（full helper），两者必须同目录保留
- 配置读取顺序：`%XDG_CONFIG_HOME%\rmux\rmux.conf` → `~/.rmux.conf` → `%APPDATA%\rmux\rmux.conf` → `%RMUX_CONFIG_FILE%`；无配置时按 best-effort 解析 `tmux.conf`（`RMUX_DISABLE_TMUX_FALLBACK=1` 关闭）
- 官方提供 Claude Code skill（`rmux claude install-skill` 装到 `%USERPROFILE%\.claude\skills\rmux`），项目级双端 skill 已在本仓库落地（`.claude/skills/rmux` + `.agents/skills/rmux`）

## 常用命令（实测可用）

```powershell
rmux new-session -d -s NAME -c D:\path
rmux split-window -h -t 1:0 -c D:\path 'cmd'   # 右分屏；-v 上下
rmux list-sessions / rmux find-panes
rmux capture-pane -t NAME -p
rmux pane-snapshot -t NAME
rmux kill-pane -t %N / kill-session -t NAME
```

## 关闭 / 退出 rmux（实测）

进程模型（`Get-CimInstance Win32_Process` 实测）：真正的 daemon 是
`libexec\rmux\rmux.exe --__internal-daemon <管道>`（本机 PID 21912），
所有会话/窗格/PTY/滚动缓冲都在 daemon 内；用户终端是 attached client
（`libexec\rmux\rmux.exe` 无参，PID 15896）；外层还有 tiny CLI `rmux.exe`（PID 14900）。
命名管道 `\\.\pipe\rmux-...` 是客户端与 daemon 的 IPC 通道。

三个退出层级（前缀键默认 `Ctrl+B`，与 tmux 一致）：

1. **只离开不杀会话（detach）**：`Ctrl+B d`（或 `Ctrl+B D` 选客户端）→ 回到外层终端，
   daemon 与会话全部保留，之后 `rmux attach-session -t 0` 回来。外部命令行可用
   `rmux detach-client -a`（注意：会断开所有客户端）。
2. **关掉当前会话/窗格**：窗格内 shell 输入 `exit`（或 `Ctrl+D`），最后一个窗格关闭后
   会话结束；快捷键 `Ctrl+B x`（杀窗格，y 确认）、`Ctrl+B &`（杀窗口）、
   `Ctrl+B :` 后输入 `kill-session`。外部 `rmux kill-session -t NAME` 实测只影响目标会话，
   daemon 与其他会话原样存活。
3. **彻底关闭 rmux**：`rmux kill-server`（无参数）→ 杀 daemon 及全部会话/窗格/PTY。
   也可在 `Ctrl+B :` 命令模式输入 `kill-server`。验证：`Get-Process rmux` 无残留、
   命名管道消失。兜底：`Stop-Process -Name rmux -Force`（或 `rmux-daemon.exe`）。

注意：本项目 Codex（左窗格）与 claude（右窗格）都跑在会话 0 内，kill-server 或关闭最后
一个会话会同时终止两侧进程；detach 不会。

## 独立终端窗口运行 claude（不开窗格，实测）

适用：不想在 Codex 主窗口分屏，弹一个独立 Windows Terminal 窗口给 claude，从这边用
rmux 命令驱动。正确链路是 **wt 窗口 → rmux → claude**：窗口自己跑 `rmux new-session -A`
（会话存在则 attach，不存在则创建并运行 claude），daemon 由窗口环境启动。

```powershell
# 0. 关键：清掉 Codex 沙箱环境注入的污染
#    - NO_COLOR=1 会一路传给 daemon→窗格→claude，把颜色全禁掉（必须 Remove-Item，置空无效）
#    - TERM=dumb 会让 rmux 客户端无色彩 → 设为 xterm-256color
#    - 重建 PATH（含 .local\bin），否则 claude /status 会报 native PATH 警告
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'
$env:COLORTERM = 'truecolor'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# 1. 弹独立 wt 窗口（-w new 强制新窗口；-WindowStyle Minimized 最小化启动不抢 Codex 焦点；
#    wt 路径动态解析，勿硬编码 WindowsApps）
$wt = (Get-Command wt.exe).Source
$wtArgs = '-w new --title "Claude Code" -d D:\ohmypwsh pwsh -NoProfile -Command "rmux new-session -A -s claude -c D:\ohmypwsh claude"'
Start-Process -FilePath $wt -ArgumentList $wtArgs -WindowStyle Minimized

# 2. 从这边操作（同窗格套路）
rmux list-clients                          # 检查 [宽x高 term] 标记：dumb=无色彩
rmux send-keys -t claude --wait quiet --stable-for 800ms --timeout 15s -- '/status' Enter
rmux capture-pane -t claude -p
```

补充：
- **无色彩的真正根因是 NO_COLOR=1**（Codex 沙箱注入），不是客户端 TERM：早期流程
  「Codex 侧 `new-session -d` 预建会话 + wt 再 attach」会把 NO_COLOR 带进 daemon → claude 单色；
  改为窗口直接 `new-session -A` 并 `Remove-Item Env:NO_COLOR` 后恢复彩色（实测确认）。
- daemon 生命周期：最后一个会话被 kill 后 daemon 自动退出（实测 `kill-session` 末会话后
  `list-sessions` 报 no server running）。
- 旧窗口需要重开时，`rmux detach-client -t <client-id>` 断开后 wt 标签页自动关闭
  （attach 进程退出 → 默认 closeOnExit graceful）。
- 实测 /status 零警告：重建 PATH（含 `.local\bin`）后 claude 读到正确 PATH。

## 踩坑（实测沉淀）

1. **send-keys 目标**：`-t` 接受会话名 / `session:window.pane` / pane id（`%N`），payload 必须放在 `--` 之后，键名 `Enter`/`Down`/`Up`/`C-c`。
2. **tiny CLI 误报「can't find pane」**：默认 `rmux.exe`（tiny 分发器）对部分目标解析失败；设 `RMUX_DISABLE_TINY_CLI=1` 走 full helper 可解（本次实测 `-t 1` 在 tiny 下报错、full helper 下 exit 0）。
3. **`--wait` 本版本只支持 `quiet`**（`--wait-next-text`/`--wait-visible-text` 是独立参数，不是 `--wait` 的值）；等待必须配 `--timeout`，避免盲 sleep。
4. **Windows ConPTY 备屏捕获限制**：Claude Code 等全屏 TUI 走 alternate screen，rmux 0.10 `capture-pane`/`pane-snapshot` 返回空（`capture-pane -a` 报 no alternate screen），无法从外部读取 TUI 渲染内容；键可发（`broadcast-keys`/`send-keys`），但输入通道对 TUI 窗格不稳定（偶发 `server closed connection before a complete response frame arrived`）。
5. **`rmux claude`（teammate 模式）**：自动传 `--teammate-mode tmux` 并注入私有 tmux shim；内层会话 socket 每实例随机（`-L` 无法预知），外层命令看不到内层会话；TUI 内容同样不可捕获。调试建议改用 `claude -p`（纯文本可捕获）或让用户目视窗格。
6. **发送键到未知窗格有副作用**：`send-keys` 目标错误会把键注入错误的 pane（实测曾把 echo 打进其他 agent 会话输入框）。发送前先 `find-panes` 确认目标。
7. **中文输入经 send-keys 丢失/乱码**：对 Claude Code 窗格发中文 payload（如 `-- '只回复"连接正常"' Enter`）时输入框不显示内容，且产生 `server closed connection before a complete response frame arrived`（乱码字节打到 API）；同一窗格英文 payload 立即正常。驱动 claude 的 prompt 先用 ASCII/英文，或先 `claude -p` 走管道传中文。

## 与本项目的关系

- 双端 skill：`.claude/skills/rmux/SKILL.md`（Claude Code 项目级）与 `.agents/skills/rmux/SKILL.md`（Codex 项目级，仓库根向上扫描）内容同源
- Claude Code 的 statusline 命令经 `pwsh` 运行，与 rmux 无直接依赖；rmux 用于分屏调试
