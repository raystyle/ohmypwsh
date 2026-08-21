# ohmypwsh

Windows 智能体环境一键部署、配置、备份与镜像平移 CLI。

原生 PowerShell 5.1 启动 → 升级 pwsh7 → 部署 `omp` 模块 → 管理工具与 agent →
部署 Windows 容器 Docker 与 WSL 基础镜像 → 跨机还原。

## 特性

- **一键 Bootstrap**：PS5.1 → pwsh7 → `omp` 模块
- **工具管理**：pin / deploy / update / status / daily，官方哈希校验
- **Agent 配置**：Codex / Claude Code / Kimi Code / Reasonix / starship，幂等
- **安全防护**：Claude Code / Codex 密钥泄露 hook
- **Windows 容器**：Docker Engine 官方二进制接管
- **WSL**：引擎更新 + ohmywsl 基础镜像构建 / 导入
- **备份迁移**：`pack` / `unpack` + `.wsl` + Docker 数据

## 快速开始

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\ohmypwsh\scripts\bootstrap.ps1
```

之后用 pwsh7：

```powershell
pwsh -NoProfile -File D:\ohmypwsh\scripts\ohmyenv.ps1 deploy all
```

## 部署流程

| 步骤 | 命令 |
| --- | --- |
| 1. Bootstrap | `bootstrap.ps1` |
| 2. 工具 | `ohmyenv.ps1 deploy all` |
| 3. Agent 配置 | `set-codex-statusline / set-claude-config / set-reasonix / ...` |
| 4. Windows 容器 | `set-docker.ps1` |
| 5. WSL | `set-wsl.ps1` + `build-wsl-image.ps1` + `set-wsl-distro.ps1` |
| 6. 备份迁移 | `ohmyenv.ps1 pack` / `unpack` |

## 软件清单

### 工具

`pwsh · codex · git · gh · age · sops · aria2 · 7z · gsudo · oscdimg · dotnet · fnm · bun · uv · python · rg · jq · yq · rmux · starship · just · ast-grep · nushell · rust · vsbuild`

### Agent

| Agent | 模型 / 配置 |
| --- | --- |
| Codex | DeepSeek，`~/.codex/config.toml` |
| Claude Code | GLM，`~/.claude/settings.json` |
| Kimi Code | Kimi，`~/.kimi-code` |
| Reasonix | DeepSeek，`%APPDATA%\reasonix` |
| Shell | starship，profile |

### 环境

| 组件 | 脚本 |
| --- | --- |
| Windows 容器 Docker | `set-docker.ps1` |
| WSL 引擎 | `set-wsl.ps1` |
| ohmywsl 镜像 | `build-wsl-image.ps1` / `set-wsl-distro.ps1` |

## 项目结构

```text
ohmypwsh/
├─ AGENTS.md           协作规则 / 目录分类 / 常用命令 / 提交约定
├─ README.md           项目入口
├─ CHANGELOG.md        变更记录
├─ ROADMAP.md          阶段与里程碑
├─ .secrets/           密钥 SOPS 加密副本
├─ docs/
│  ├─ plans/           方案与决策
│  └─ research/        研究 / 踩坑
└─ scripts/
   ├─ bootstrap.ps1    初始部署入口
   ├─ ohmyenv.ps1      CLI
   ├─ helpers.ps1      核心函数
   ├─ env.psd1         pin 清单
   ├─ set-*.ps1        幂等配置脚本
   ├─ hooks/           hook 脚本
   └─ wsl/             WSL 组件脚本
```

## 路线

| 阶段 | 状态 |
| --- | --- |
| 0–3 基础设施 / 依赖 / 密钥 / Codex | 已完成 |
| 4 工具扩展 | 进行中 |
| 5 可迁移 Agent 环境 CLI | 进行中 |
| 6 Windows 容器 + WSL 平移 | 进行中 |

详见 `ROADMAP.md`。

## 文档

- `AGENTS.md` — 最高约束与常用命令
- `docs/README.md` — 文档地图 / 目录索引
- `docs/plans/0010-portable-agent-env.md` — 可迁移架构
- `docs/plans/0011-windows-agent-env-oneclick.md` — 一键平移
