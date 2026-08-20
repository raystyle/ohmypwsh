# ohmypwsh

Agent 环境部署与管理模块 CLI：从 Windows 原生 PowerShell 5.1 一键初始化，升级 PowerShell 7，
部署完整 PowerShell 模块 CLI，再安装 / 管理工具与 agent 环境（pwsh / gh / git / age / sops /
codex / aria2 / 7z / uv / python / rg / jq / yq / rmux / starship 到 `D:\ohmyenv`，Codex /
Claude Code / Kimi Code 配置与密钥由脚本幂等接管）。

所有已部署产物（工具 + 配置 + 密钥）支持打包压缩，在另一台 Windows 上通过产物压缩包一键还原
已 pin 的软件工具环境。

## 三条主链

- Bootstrap：原生 PS5.1 → 升级 pwsh7 → 部署模块 CLI
- 管理：工具 / PowerShell 模块 / agent 配置 / 密钥（age + SOPS）
- 迁移：产物打包 → 压缩包 → 跨机还原已 pin 工具环境

## 入口

- `AGENTS.md`：协作规则、目录分类、常用命令、提交约定（最高约束）
- `docs\README.md`：文档地图、命名约定、项目目录与文件索引
- `docs\plans\0010-portable-agent-env.md`：项目本质定位与可迁移架构方案
- `scripts\`：ohmyenv CLI、模块管理器与环境脚本
- `CHANGELOG.md` / `ROADMAP.md`：变更记录与阶段状态
