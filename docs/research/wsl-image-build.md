# ohmywsl WSL 基础镜像构建（接管 D:\ohmywsl2）

## 目标

在 ohmyenv 内构建可迁移的 WSL 基础镜像（`.wsl` 产物），后续 WSL 扩展增量安装与主项目
ohmyenv 一致（按工具 pin/update/deploy）。

## 产物

- `D:\ohmyenv\images\wsl\ohmywsl-<版本>-wsl-amd64.wsl`
- `D:\ohmyenv\images\wsl\ohmywsl-<版本>-wsl-amd64.report.json`（SHA256 + 工具版本清单）

首次构建（2026-08-21）：`ohmywsl-0.1.0-wsl-amd64.wsl`，1.65 GB，dev 变体。

## 构建流程（`scripts\build-wsl-image.ps1`）

1. 官方 Ubuntu 24.04.4 WSL 镜像下载到 EnvRoot 缓存（SHA256 校验）
2. `wsl --import ohmyenv-wsl-build`（`--set-sparse true` 使 VHD 稀疏）
3. `base/base-config.sh`（用户 ray / sudo / wsl.conf / .bashrc.d / 时区 / locale / linger）
4. `base/apt-sources.sh`（清华源 + 系统编译底座）
5. `base/git.sh`
6. `dev/node.sh`（fnm）→ `bun.sh` → `rust.sh` → `uv.sh` → `go.sh` → `zig.sh`
7. `tool-versions.sh` 采集版本
8. `clean.sh` 深度清理（machine-id / SSH host keys / 缓存 / 敏感文件扫描）
9. `wsl --export` + gzip → `.wsl`
10. 生成 report.json + 注销构建 distro

## 基础镜像清单（dev 变体）

- 系统：curl/wget/jq/python3-pip/build-essential/cmake/ninja/pkg-config/libssl-dev/mingw-w64
- node：fnm 1.39.0 + Node LTS（npmmirror）
- bun：最新 stable（npmmirror 优先）
- rust：rustup + stable（rsproxy.cn）+ linux-gnu/musl/windows-gnu targets + rust-analyzer
- uv：最新（清华 PyPI）
- go：最新 stable（golang.google.cn / goproxy.cn）+ gopls
- zig：最新 stable（官方预编译）+ zls

明确不进镜像：vault/凭证、AI agent、hosts 加速、zsh、gh（目标机增量部署）。

## 踩坑沉淀

- **WSL DNS 代理 `10.255.255.254` 不解析**：`.wslconfig` 的 `dnsTunneling=true` 会强制 WSL
  用该代理；本机该代理解析超时。改为 `dnsTunneling=false` 后 WSL 直接继承网卡 DHCP DNS
  （本机 192.168.88.1），`apt update` 恢复。镜像不硬编码 DNS。
- **releases.ubuntu.com 之前 aria2 TLS 失败是网络不稳定，非 aria2 本身**：网络稳定后 aria2
  实测 18MiB/s 下载 373MB Ubuntu 镜像成功（部分连接报 schannel handle 错误但整体 OK）；
  下载保持 `Save-ReleaseAsset`（aria2 主通道）优先。
- **WSL 命令输出 UTF-16 乱码**：`wsl --import` 的 stderr 警告（VHD 非稀疏 / 过时配置）需
  `2>$null` 抑制，并在导入后 `wsl --manage <distro> --set-sparse true --allow-unsafe`。
- **`fnm current` 无节点时返回 `none` 且退出码 0**：不能用 exit code 判断是否已装，须比较
  输出 `!= "none" / "system"`（node.sh 首次 build 因误判跳过安装）。
- **构建失败保留现场**：构建 distro 只在成功路径注销；`catch` 保留 `ohmyenv-wsl-build` 供
  `wsl -d` 调试，避免失败即销毁现场。
- **Rust stable 版本确认**：2026-08 发布 train 已到 1.98.0（rustc/cargo 1.98.0）。
