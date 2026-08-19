# ohmypwsh

个人 Windows 环境依赖管理项目：用 `scripts\ohmyenv.ps1` 自举安装并管理 gh / git / age / sops / codex / aria2 / 7z / rg / jq / yq 到 `D:\ohmyenv`；密钥走 age + SOPS（`.secrets\` 加密副本），Codex 配置（沙箱 / DeepSeek / 状态栏）由脚本幂等接管。

## 入口

- `AGENTS.md`：协作规则、目录分类、常用命令、提交约定（最高约束）
- `docs\README.md`：文档地图、命名约定、项目目录与文件索引
- `scripts\`：ohmyenv CLI 与环境脚本
- `CHANGELOG.md` / `ROADMAP.md`：变更记录与阶段状态
