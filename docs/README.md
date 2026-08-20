# 文档规范

## 文档地图

| 文档 | 用途 | 维护时机 |
| --- | --- | --- |
| `AGENTS.md` | 协作规则（本项目的最高约束） | 新增/修改规则时 |
| `CHANGELOG.md` | 可交付变更记录 | 每次可交付变更 |
| `ROADMAP.md` | 阶段、里程碑与状态 | 阶段启动/完成/变更时 |
| `docs\plans\NNNN-短名.md` | 重要方案/决策 | 方案立项、评审、实施、废弃时 |
| `docs\research\主题.md` | 研究文档（工具能力、踩坑沉淀、实测记录） | 完成研究或踩坑时即时维护 |

## 命名与结构

- 方案文档统一放在 `docs\plans\`，文件名 `NNNN-短名.md`（4 位递增编号 + 英文短横线短名），模板见 `0000-template.md`
- 研究文档统一放在 `docs\research\`，文件名 `英文短名.md`（短横线分隔），记录主题、现状、结论与待办
- 全项目文件分类定义见 `AGENTS.md`「目录与分类规范」（脚本 / 文档 / 配置 / 密钥数据 / 环境目录）
- 状态词统一：
  - 方案：`草稿` / `评审中` / `已批准` / `实施中` / `已完成` / `已废弃`
  - 阶段：`未开始` / `进行中` / `已完成` / `挂起`
- 正文以中文为主，命令、代码、专有名词保留原文

## 变更流程

1. 重要决策先立方案文档（`docs\plans\`），批准后实施
2. 实施时同步更新 `ROADMAP.md` 阶段状态
3. 完成时向 `CHANGELOG.md` 的 `[Unreleased]` 追加记录

只改代码、不同步上述文档视为变更不完整（AGENTS.md 规则 3）。

## 方案索引

- `0001-env-deps.md`：环境依赖管理（gh/git 自举安装，bootstrap 不依赖 gh）
- `0002-codex-takeover.md`：Codex 接管（原生二进制 + 沙箱 + DeepSeek 密钥）
- `0003-tools-takeover.md`：D:\Oh-My-Claude 工具批量接管（rg/jq/yq）
- `0004-tool-tiers.md`：工具分层、引导安装顺序与日常无影响更新
- `0005-starship-takeover.md`：starship 接管（配置保留）与 PowerShell 模块/调试清理
- `0006-psmodule-manager.md`：PowerShell 模块管理器（在线/离线、PS5/PS7、自研模块打包）
- `0007-uv-python-takeover.md`：uv/Python 接管（uv 最新 + Python 3.12 为准）
- `0008-claude-code-config.md`：Claude Code 扩展配置（GLM-5.3 1M 上下文）
- `0009-claude-takeover.md`：Claude Code 完全接管（YOLO/状态栏/env 收敛/omc 清理；rmux skill 已迁至 win-rmux 独立仓库）

## 研究文档

- `research\gh-cli.md`：gh（GitHub CLI）能力研究（版本/认证/API 兜底/命令地图/衔接建议）
- `research\gh-git-https-ssh.md`：gh 与 git 的 HTTPS / SSH 互相配置（Windows 指南 + 本机实测）
- `research\age-sops-key-management.md`：密钥管理（age + SOPS，接入 ohmyenv）
- `research\ohmyenv-pitfalls.md`：ohmyenv 踩坑沉淀
- `research\codex-deepseek-config.md`：Codex 接管记录（原生二进制 + 沙箱 + DeepSeek 密钥 + 状态栏）
- `research\codex-statusline.md`：Codex TUI 状态栏研究（全量可选项 / 样式机制 / 推荐配置）
- `research\starship-config.md`：starship.toml 配置研究（PowerShell 专用提示行）
- `research\powershell-dotnet-vsbuild.md`：PowerShell 模块 / .NET 库 / VS Build Tools 现状研究
- `research\omc-psmodule-management.md`：omc 的 PowerShell 模块管理机制（本地仓库 + 双 shell 交叉部署 + 锁文件）
- `research\powershell-encoding.md`：PS5/PS7 编码兼容研究（优先注意规则）
- `research\claude-code-statusline-api.md`：Claude Code 状态栏（statusLine）API 契约研究
- `research\claude-code-onboarding.md`：Claude Code 首次启动 onboarding 与安装警告（登录验证 / 工作区信任 / .local PATH 检查踩坑）
- `research\node-fnm.md`：Node.js/npm 接管（fnm，弃用 nvm-windows，`.nvmrc` 无缝切换）
- `research\bun.md`：Bun 接管（oven-sh/bun + `bunfig.toml` npmmirror）
- `research\gsudo.md`：gsudo 接管（gerardog/gsudo，命令统一叫 `gsudo`，避开 Windows 内置 sudo）
- `research\oscdimg.md`：oscdimg 接管（微软符号服务器固定 URL + FileVersion，ISO 制作工具）

## 项目目录索引

```text
ohmypwsh/
├─ AGENTS.md                    协作规则（最高约束）：规则 1-4、目录分类、设计原则
├─ README.md                    项目入口（一句话定位 + 文档/脚本链接）
├─ CHANGELOG.md                 可交付变更记录（先维护在 [Unreleased]）
├─ ROADMAP.md                   阶段与里程碑状态（未开始/进行中/已完成/挂起）
├─ .sops.yaml                   SOPS 加密策略（age 公钥，可提交）
├─ .gitignore                   忽略规则（备份/缓存/密钥明文兜底）
│
├─ .secrets\                    密钥加密副本（可提交；明文禁止入库）
│  └─ deepseek.env.enc          DeepSeek key 的 SOPS 加密备份
│
├─ docs\                        文档总览与规范见本文件
│  ├─ README.md                 文档地图、命名约定、变更流程、目录索引
│  ├─ plans\                    重要方案/决策（NNNN-短名.md，模板 0000）
│  │  ├─ 0000-template.md       方案文档模板
│  │  ├─ 0001-env-deps.md       环境依赖管理（gh/git 自举，bootstrap 不依赖 gh）
│  │  ├─ 0002-codex-takeover.md Codex 接管方案（原生二进制 + 沙箱 + 密钥）
│  │  ├─ 0003-tools-takeover.md rg/jq/yq 工具批量接管（omc → ohmyenv）
│  │  ├─ 0004-tool-tiers.md     工具分层与日常无影响更新（核心基础/扩展 + daily）
│  │  ├─ 0005-starship-takeover.md starship 接管与 PowerShell 清理
│  │  ├─ 0006-psmodule-manager.md PowerShell 模块管理器（在线/离线/双 shell）
│  │  └─ 0007-uv-python-takeover.md uv/Python 接管（uv 最新 + Python 3.12 为准）
│  └─ research\                 研究文档（工具能力 / 踩坑沉淀 / 实测记录）
│     ├─ gh-cli.md              gh CLI 研究（现状/认证/API 兜底/命令地图）
│     ├─ gh-git-https-ssh.md    gh 与 git 的 HTTPS/SSH 互相配置（本机实测）
│     ├─ age-sops-key-management.md  密钥管理（age + SOPS 接入 ohmyenv）
│     ├─ ohmyenv-pitfalls.md    ohmyenv 踩坑沉淀
│     ├─ codex-deepseek-config.md    Codex 接管记录（沙箱/密钥/状态栏）
│     ├─ codex-statusline.md    Codex TUI 状态栏研究（全量可选项/样式/推荐配置）
│     └─ powershell-encoding.md PS5/PS7 编码兼容研究（优先注意规则）
│
└─ scripts\                     环境脚本（全部入口）
   ├─ ohmyenv.ps1               CLI：query / deploy / install / update / pin / status
   ├─ helpers.ps1               模块函数（下载、安装、Invoke-GitHubApi 限流兜底）
   ├─ env.psd1                  工具版本锁定清单（唯一 pin 来源，版本不硬编码）
   ├─ omp.psm1                  PowerShell 7 模块（omp 别名 → Invoke-Omp）
   ├─ omp.psd1                  模块清单（ModuleVersion / 导出 / 元数据）
   ├─ deploy-omp.ps1            部署 omp 模块到 EnvRoot\modules\omp + 注册 PSModulePath
   ├─ bootstrap.ps1             PS5.1 人类初始部署入口（装 pwsh7 + 部署 omp + 注册 EnvRoot）
   ├─ modules.psd1              PowerShell 模块锁定清单（psmodule.ps1 维护）
   ├─ psmodule.ps1              PowerShell 模块管理器（在线/离线、PS5/PS7、打包）
   ├─ set-deepseek-key.ps1      DeepSeek API Key 交互式设置（用户级环境变量）
   ├─ set-codex-statusline.ps1  Codex 状态栏幂等合并（[tui] status_line）
   ├─ set-starship-config.ps1   starship PowerShell 配置（全模板幂等，-Force 覆盖）
   ├─ set-nushell-config.ps1    官方 nushell 插件注册（nu_plugin_* 逐个 plugin add，幂等）
   ├─ set-rust.ps1              Rust 接管（rustup + stable + rsproxy.cn 镜像，幂等）
   ├─ set-vsbuild.ps1           VS Build Tools 接管（离线布局 --noWeb 安装，需提权，幂等）
   ├─ set-docker.ps1            Windows 容器 Docker Engine 接管（官方 static 二进制 + 服务注册，需提权）
   ├─ set-wsl.ps1               WSL 安装/更新（microsoft/WSL 官方 x64 MSI，需提权）
   ├─ set-wsl-distro.ps1        WSL 镜像导入/部署（.wsl 产物 → distro，参考 ohmywsl2）
   ├─ set-claude-key.ps1        Claude Code (GLM) API Key 设置/迁移（-FromOmcProfile）
   ├─ set-claude-config.ps1     Claude Code 配置（安装 + env + settings.json 合并）
   ├─ sops-encrypt-anthropic.ps1 ANTHROPIC_API_KEY SOPS 加密备份
   ├─ sops-encrypt-deepseek.ps1 SOPS 重加密/回读验证
   ├─ sops-test.ps1             SOPS 冒烟测试
   ├─ verify-codex-handover.ps1 Codex 交接验证（原生版解析 PASS/FAIL）
   └─ verify-tools-handover.ps1 rg/jq/yq 交接验证（解析/版本 PASS/FAIL）
```

外部环境目录（git 之外，由 ohmyenv 管理）：`D:\ohmyenv` —— gh / git / age / sops / codex / aria2 / 7z / uv / python / rg / jq / yq / rmux / starship / just / ast-grep / nushell / rust / vsbuild / docker（docker-data） 安装根；`D:\ohmyenv\modules` 为 PowerShell 模块共享部署根（用户 PSModulePath 追加）；`uv-cache` / `uv-tools` 为 uv 缓存与工具目录。

> 目录分类规则见 `AGENTS.md`「目录与分类规范」；本索引随文件增删同步维护。
