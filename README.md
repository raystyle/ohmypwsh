# ohmypwsh

Windows 智能体环境一键部署、配置、备份与镜像平移 CLI。从 Windows 原生 PowerShell 5.1 出发，
一键完成：升级 PowerShell 7 → 部署模块 CLI → 安装/管理工具与 agent（Codex / Claude Code /
Kimi Code）→ 配置 Windows 容器 Docker → 安装 WSL 并构建/导入 ohmywsl 基础镜像；所有产物
（工具 + 配置 + 密钥 + WSL 镜像 + Docker 数据）可打包压缩，在另一台 Windows 上还原已 pin 环境。

## 核心能力

- **Bootstrap**：原生 PS5.1 一键初始化（提前装 aria2 → 升级 pwsh7 → 部署 omp 模块 → 注册 PATH/EnvRoot）。
- **管理**：工具（`ohmyenv`）、PowerShell 模块（`psmodule`）、agent 配置、密钥（age + SOPS）幂等管理。
- **Windows 容器**：Docker Engine 官方 static 二进制接管 + 服务注册 + data-root 归 EnvRoot。
- **WSL**：WSL 引擎安装/更新 + ohmywsl 基础镜像构建（`.wsl`）/ 导入 distro。
- **备份 / 平移**：`ohmyenv pack/unpack` + `.wsl` 镜像 + Docker data-root 归档，跨机还原。

## 完整部署操作过程

### 1. 初始 Bootstrap（干净 Windows，仅原生 PS5.1）

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\ohmypwsh\scripts\bootstrap.ps1
```

完成：aria2 提前安装 → 装/升级 pwsh7 → 部署 `omp` 模块 → 注册 `OHMYENV_ROOT` 与 PATH。

### 2. 工具部署（pwsh7）

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
pwsh -NoProfile -File D:\ohmypwsh\scripts\ohmyenv.ps1 status
pwsh -NoProfile -File D:\ohmypwsh\scripts\ohmyenv.ps1 deploy all     # 或 pin/update/daily
```

### 3. Agent 配置（幂等）

```powershell
pwsh -NoProfile -File D:\ohmypwsh\scripts\set-codex-statusline.ps1
pwsh -NoProfile -File D:\ohmypwsh\scripts\set-claude-config.ps1
pwsh -NoProfile -File D:\ohmypwsh\scripts\set-claude-statusline.ps1
pwsh -NoProfile -File D:\ohmypwsh\scripts\set-reasonix.ps1
pwsh -NoProfile -File D:\ohmypwsh\scripts\set-starship-config.ps1
# set-deepseek-key / set-claude-key：交互式写入密钥 + SOPS 加密备份
```

### 4. Windows 容器 Docker（需提权）

```powershell
pwsh -NoProfile -File D:\ohmypwsh\scripts\set-docker.ps1
docker info   # windowsfilter / OSType windows
```

### 5. WSL 引擎 + 基础镜像

```powershell
pwsh -NoProfile -File D:\ohmypwsh\scripts\set-wsl.ps1          # 更新 WSL 引擎
pwsh -NoProfile -File D:\ohmypwsh\scripts\build-wsl-image.ps1  # 构建 ohmywsl 基础镜像
pwsh -NoProfile -File D:\ohmypwsh\scripts\set-wsl-distro.ps1   # 导入为 distro
```

### 6. 备份 / 镜像平移

```powershell
pwsh -NoProfile -File D:\ohmypwsh\scripts\ohmyenv.ps1 pack     # 工具+配置+密钥打包
pwsh -NoProfile -File D:\ohmypwsh\scripts\ohmyenv.ps1 unpack <zip>  # 目标机还原
# WSL：拷贝 D:\ohmyenv\images\wsl\*.wsl；Docker：docker save / data-root 归档
```

## 项目结构

```text
ohmypwsh/
├─ AGENTS.md                  协作规则 / 目录分类 / 常用命令 / 提交约定
├─ README.md                  项目入口（本文）
├─ CHANGELOG.md               变更记录
├─ ROADMAP.md                 阶段与里程碑状态
├─ .sops.yaml                 SOPS 加密策略（age 公钥）
├─ .secrets/                  密钥 SOPS 加密副本（明文不入库）
├─ docs/
│  ├─ README.md               文档地图 / 命名约定 / 目录索引
│  ├─ plans/                  方案与决策（0010 可迁移架构 / 0011 一键平移）
│  └─ research/               研究 / 踩坑沉淀
└─ scripts/
   ├─ bootstrap.ps1           PS5.1 初始部署入口
   ├─ ohmyenv.ps1             CLI：query/deploy/install/update/pin/status/daily/pack/unpack
   ├─ helpers.ps1             核心函数（下载 / API 兜底 / 哈希校验）
   ├─ env.psd1                工具版本 pin 清单（唯一来源）
   ├─ modules.psd1            PowerShell 模块 pin 清单
   ├─ set-*.ps1               agent / 工具 / 环境幂等配置脚本
   ├─ build-wsl-image.ps1     构建 ohmywsl WSL 基础镜像
   └─ wsl/                    WSL 组件脚本（base/dev/clean/tool-versions）
```

## 软件功能清单

### 工具（ohmyenv 管理，pin 版本 + 官方哈希校验）

| 类别 | 工具 |
| --- | --- |
| 智能体 / 运行时 | pwsh、codex、fnm、node、bun、rust、vsbuild |
| 项目管理 | git、gh、just、ast-grep |
| 密钥 | age、sops |
| 下载 / 基础 | aria2、7z、gsudo、oscdimg |
| 开发 / CLI | dotnet、uv、python、rg、jq、yq、rmux、starship、nushell |

### Agent 配置

| Agent | 内容 |
| --- | --- |
| Codex | DeepSeek 模型、`config.toml`、状态栏 |
| Claude Code | GLM 模型、`settings.json`（env/YOLO/statusLine）、原生路径 |
| Kimi Code | `~/.kimi-code` 配置 + 工作区信任 |
| Reasonix Desktop | DeepSeek 密钥复用、`config.toml` + `.env`、桌面快捷方式 |
| Shell | starship 提示行、profile 守卫 |

### Windows 容器 / WSL

| 组件 | 脚本 / 产物 |
| --- | --- |
| Docker Engine | `set-docker.ps1`，data-root `D:\ohmyenv\docker-data` |
| WSL 引擎 | `set-wsl.ps1`，microsoft/WSL 官方 MSI |
| ohmywsl 镜像 | `build-wsl-image.ps1` → `D:\ohmyenv\images\wsl\*.wsl` |
| 镜像导入 | `set-wsl-distro.ps1` → distro |

### 密钥

- age 私钥 `%APPDATA%\sops\age\keys.txt`；SOPS 加密副本 `.secrets\*.enc`；明文永不入库。

## 现状与路线

详见 `ROADMAP.md`。阶段总览：

| 阶段 | 目标 | 状态 |
| --- | --- | --- |
| 0-3 | 基础设施 / 环境依赖 / 密钥 / Codex 接管 | 已完成 |
| 4 | 软件工具扩展（20+ 工具 + 日常无影响更新） | 进行中 |
| 5 | 项目重定位：可迁移 Agent 环境 CLI（bootstrap / omp / pack/unpack） | 进行中 |
| 6 | Windows 容器 + WSL 镜像平移 | 进行中 |

当前已完成：工具与 agent 接管、密钥 SOPS、bootstrap、omp 模块、pack；Docker 接管、WSL 引擎
更新、ohmywsl 基础镜像构建成功。待办：WSL 扩展增量部署、Docker 数据卷平移、跨机 unpack 实测。

## 文档入口

- `AGENTS.md`：最高约束与常用命令
- `docs\README.md`：文档地图 / 目录索引
- `docs\plans\0010-portable-agent-env.md`：可迁移架构方案
- `docs\plans\0011-windows-agent-env-oneclick.md`：一键部署/备份/镜像平移方案
- `docs\research\`：研究 / 踩坑沉淀
