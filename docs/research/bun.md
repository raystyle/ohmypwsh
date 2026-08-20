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

## 踩坑

- aria2 对 `release-assets.githubusercontent.com` 偶发 SSL/TLS handshake failure，`Save-ReleaseAsset`
  会回退 curl 兜底；bun 本次 aria2 重试后成功（36 MiB，约 1.3 MiB/s）。
