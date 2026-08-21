# 0011 Windows 智能体环境一键部署/配置/备份/镜像平移

> 2026-08-21，在 0010 基础上扩围：一键覆盖「Windows 工具 + agent 配置 + WSL + Windows 容器」。

## 定位

从 Windows 原生 PowerShell 5.1 出发，一键完成：

1. **部署**：pwsh7 → omp 模块 → 工具（ohmyenv）→ agent 配置（codex/claude/kimi）→
   Windows 容器 Docker → WSL 引擎 + 基础镜像 distro。
2. **配置**：所有 agent 配置、镜像源、PATH、密钥均为幂等脚本。
3. **备份**：工具 pin + agent 配置 + 密钥 + WSL 镜像 + Docker 数据。
4. **镜像平移**：产物压缩包 / `.wsl` 镜像 / Docker 数据卷在另一台 Windows 还原。

## 三层组件

| 层 | 内容 | 脚本 |
| --- | --- | --- |
| Windows 工具 + agent | ohmyenv 20+ 工具、codex/claude/kimi/statusline | `ohmyenv.ps1` / `set-*.ps1` |
| Windows 容器 | Docker Engine（官方 static 二进制 + 服务） | `set-docker.ps1` |
| WSL | WSL 引擎 + ohmywsl 基础镜像 | `set-wsl.ps1` / `build-wsl-image.ps1` / `set-wsl-distro.ps1` |

## 一键部署链（bootstrap）

```text
PS5.1 bootstrap.ps1
  ├─ 提前装 aria2（加速后续下载）
  ├─ 装/升级 pwsh7
  ├─ 部署 omp 模块
  └─ 注册 OHMYENV_ROOT / PATH
        ↓ pwsh7
omp deploy all                        # 工具（pin 版本 + 官方哈希校验）
set-codex/set-claude/set-kimi ...      # agent 配置（幂等）
set-docker.ps1                         # Windows 容器
set-wsl.ps1                            # WSL 引擎
set-wsl-distro.ps1                     # 基础镜像 distro（.wsl → import）
```

## 备份 / 镜像平移

- **工具 + 配置 + 密钥**：`ohmyenv pack` → 单个压缩包（portable + installers + .secrets + age），
  目标机 `ohmyenv unpack` 幂等还原。
- **WSL**：`build-wsl-image.ps1` 产出 `.wsl` 基础镜像模板（`D:\ohmyenv\images\wsl`），目标机
  `set-wsl-distro.ps1` 导入；后续扩展按工具增量部署（与主项目一致）。
- **Windows 容器**：Docker data-root 归 EnvRoot（`D:\ohmyenv\docker-data`），可用
  `docker save` 导出镜像 / 归档 data-root 随包平移；`set-docker.ps1` 在目标机重注册服务。

## 镜像源（国内加速，统一策略）

| 组件 | 源 |
| --- | --- |
| GitHub 工具/API | `gh api` 兜底（5000/h） |
| npm / node | npmmirror（fnm `FNM_NODE_DIST_MIRROR` + npm registry） |
| pip / uv | 清华 PyPI |
| rust | rsproxy.cn（rustup + cargo sparse） |
| go | golang.google.cn / goproxy.cn |
| bun | npmmirror（bun 二进制 + registry） |
| WSL apt | mirrors.tuna.tsinghua.edu.cn（security 官方） |
| Ubuntu WSL 镜像 | releases.ubuntu.com（aria2 主通道） |
| Docker 二进制 | download.docker.com |

## 缓存 / 产物目录

```text
D:\ohmyenv\
  cache\                  # 工具/镜像下载缓存
  images\wsl\             # WSL 基础镜像产物（.wsl + report.json）
  docker-data\            # Windows 容器 data-root
  logs\                   # 安装/更新日志
  deploy\                 # ohmyenv pack 产物
```

## 验收标准

1. 干净 Windows（仅 PS5.1）跑 `bootstrap.ps1` → pwsh7 + omp + 工具 + agent 配置全绿。
2. `set-docker.ps1` 后 `docker info` 显示 windowsfilter / OSType windows。
3. `set-wsl.ps1` + `set-wsl-distro.ps1` 后 `wsl -l -v` 有 ohmywsl distro 且可进入。
4. 换机：`ohmyenv unpack` + `.wsl` 导入 + Docker 服务重建，status/doctor/docker/wsl 全绿。
