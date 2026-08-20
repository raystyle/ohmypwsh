# gsudo 接管研究

> 2026-08-20，来源：gerardog/gsudo Release + `gsudo --help` 实测 + Windows 11 内置 sudo 现状。

## 现状

- gsudo：Windows 的 sudo 等价物（单二进制，无服务、无系统改动，只需加入 PATH）。
- 仓库 `gerardog/gsudo`，tag 前缀 `v`（如 `v2.6.1`）。
- Windows 资产 `gsudo.portable.zip`（约 5.7 MB），内含多架构目录：
  `x64/`、`x86/`、`arm64/`、`net46-AnyCpu/`，每个目录有 `gsudo.exe` + `gsudoModule.psd1/psm1` +
  `Invoke-gsudo.ps1` + `Invoke-ElevatedCommand.ps1`。
- `gsudo --version` 输出 `gsudo v2.6.1 (...)`。

## 部署（ohmyenv 部署包）

- `New-ToolDef`：`TagPrefix='v'`、`Repo='gerardog/gsudo'`、
  `AssetPattern='^gsudo\.portable\.zip$'`、`Dir='gsudo'`、`Bin='gsudo'`、`Exe='gsudo\gsudo.exe'`。
- 自定义解压类型 `gsudo`：`Expand-Archive` 后只取 `x64\` 展平到安装根，删除 `x86/arm64/net46-AnyCpu`。
- pin v2.6.1 → deploy 到 `D:\ohmyenv\gsudo` + 前置注册 PATH；sha256 回填。

## sudo 别名与 Windows 内置 sudo 冲突

- `scripts\set-gsudo-config.ps1` 把 `gsudo.exe` 同源复制为 `sudo.exe`（幂等，供「sudo」命令使用）。
- **注意**：Windows 11 / Server 2025（Build 26100）自带 `C:\WINDOWS\system32\sudo.exe`
  （Windows Sudo，本机已启用，版本 1.0.1）。因 Machine PATH 位于 User PATH 之前，
  `sudo` 会优先解析到 system32 的 Windows 内置 sudo，而非 gsudo。
- 结论：本机直接使用 `gsudo <cmd>` 无冲突；若确需 `sudo` 指向 gsudo，可在 pwsh profile 加
  `Set-Alias sudo gsudo`（或调整 PATH 顺序），否则 `sudo` 命中 Windows 内置 sudo。

## 授权缓存（UAC 一次后一段时间内免重复）

- 默认缓存：gsudo 会在当前控制台会话内缓存提权令牌，一段时间内重复 `gsudo` 不再弹 UAC。
- 显式缓存会话：`gsudo cache on`（关闭 `gsudo cache off`，查看 `gsudo status`）。

## 踩坑

- `gsudo.portable.zip` 是多架构目录，不能用默认 zip 单目录展平（有 4 个顶层目录），需专用
  `gsudo` 解压类型只保留 x64。
- `sudo.exe` shim 只是同名复制，`--help`/`--version` 仍显示 `gsudo`（程序名不随文件名变化）。
