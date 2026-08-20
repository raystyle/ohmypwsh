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

## 命令命名：只用 gsudo，不建 sudo 别名

- **决策（用户指示）**：命令统一叫 `gsudo`，不创建 `sudo.exe` 别名，避免与 Windows 内置
  sudo 冲突。
- **冲突背景**：Windows 11 / Server 2025（Build 26100）自带 `C:\WINDOWS\system32\sudo.exe`
  （Windows Sudo，本机已启用，版本 1.0.1）。因 Machine PATH 位于 User PATH 之前，若建
  `sudo.exe` 也会被 system32 的 Windows 内置 sudo 抢先命中。
- 使用方式：`gsudo <命令>`、`gsudo { PowerShell 脚本块 }`、`gsudo`（提升当前 shell）。

## 授权缓存（UAC 一次后一段时间内免重复，按需开启）

- 默认 `CacheMode=Explicit`：每次提权都弹 UAC，除非手动开启缓存会话。
- 会话级缓存（无需改配置、无需提权）：`gsudo cache on`（关闭 `gsudo cache off`，查看
  `gsudo status`）。
- 自动缓存：`gsudo config CacheMode Auto`（首次弹 UAC 后自动开缓存会话，`CacheDuration`
  默认 5 分钟）。注意：`CacheMode` 属于全局系统设置，需提权写入（实测本机走
  `HKLM:\SOFTWARE\gsudo`）；不默认开启。

## 踩坑

- `gsudo.portable.zip` 是多架构目录，不能用默认 zip 单目录展平（有 4 个顶层目录），需专用
  `gsudo` 解压类型只保留 x64。
- `gsudo config CacheMode Auto` 会触发提权并写入全局（HKLM），不是 per-user 配置；
  若要回退默认：`gsudo config CacheMode --global --reset`。
