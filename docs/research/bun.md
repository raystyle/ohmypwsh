# Bun 接管研究

> 2026-08-20，来源：oven-sh/bun Release + `bun --help` 实测 + 用户指示。

## 现状

- Bun：快速 JavaScript 运行时 + 包管理器 + 打包器 + 测试运行器（单二进制）。
- 仓库 `oven-sh/bun`，tag 前缀 `bun-v`（如 `bun-v1.3.14`）。
- Windows x64 资产 `bun-windows-x64.zip`，解压为单文件 `bun.exe`（约 98 MB）。
- `bun --version` 输出 `1.3.14`；`bun --help` 显示 `(1.3.14+0d9b296af)`。

## 部署（ohmyenv 部署包）

- `New-ToolDef`：`TagPrefix='bun-v'`、`Repo='oven-sh/bun'`、
  `AssetPattern='^bun-windows-x64\.zip$'`、`Dir='bun'`、`Bin='bun'`、`Exe='bun\bun.exe'`。
- pin v1.3.14 → deploy 到 `D:\ohmyenv\bun` + 前置注册 PATH；sha256 回填。

## 镜像源配置

- 全局配置：`~/.bunfig.toml`（`%USERPROFILE%\.bunfig.toml`，对所有项目生效）。
- 局部配置：项目根 `bunfig.toml`（与 `package.json` 同级，仅当前项目生效）。
- 内容：

```toml
[install]
registry = "https://registry.npmmirror.com"
```

- 沉淀为 `scripts\set-bun-config.ps1`（幂等：全局 + 局部，缺 `[install]` 补头，重复 registry 行去重）。

## bunx（Windows 下缺失，需同目录 shim）

- bun 单二进制部署到 `D:\ohmyenv\bun\bun.exe` 后，**Windows 上默认没有 `bunx` 命令**
  （Linux 发行包自带 `bunx` 符号链接；Windows zip 不含）。官方 Windows PowerShell 安装器会额外
  创建 `bunx.exe`（bun 内部按 `argv[0]` 是否 `bunx` 切换到 bunx 模式）。
- 方案：`Install-ToolVersion` 新增 `Ensure-BunxShim`，在 zip 解压分支 + 跳过快速路径为 bun
  部署目录创建 `bunx.exe` **硬链接 → bun.exe**（NTFS 支持），`bunx` 即 `bun x`。实测
  `bunx prettier --version` → 3.9.6、`bunx cowsay` 正常。
- 硬链接失败（非 NTFS）回退 `bunx.cmd`：`@echo off` + `"%~dp0bun.exe" x %*`。

## 踩坑

- aria2 对 `release-assets.githubusercontent.com` 偶发 SSL/TLS handshake failure，`Save-ReleaseAsset`
  会回退 curl 兜底；bun 本次 aria2 重试后成功（36 MiB，约 1.3 MiB/s）。
- bunx.cmd 兜底 shim 中 `%~dp0bun.exe` 必须加引号：可重定位环境下部署目录可能含空格，无引号时
  cmd 把路径拆成多个 token、把 `bun` 当命令报 `'bun' is not recognized`；`"%~dp0bun.exe" x %*`
  实测在带空格临时目录下正常。
