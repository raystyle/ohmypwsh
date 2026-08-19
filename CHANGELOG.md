# Changelog

本项目变更记录，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

### Added

- 建立 `AGENTS.md` 规则 1：踩坑必须当场沉淀为脚本或文档命令
- 建立 `AGENTS.md` 规则 2：环境感知，默认使用 pwsh（PowerShell 7）
- 建立 `AGENTS.md` 规则 3：文档规范（CHANGELOG / ROADMAP / `docs\plans\` 方案文档）
- 建立 `docs\` 文档骨架：`docs\README.md` 总览与 `docs\plans\0000-template.md` 方案模板
- 建立 `AGENTS.md` 设计原则：引导安装不依赖 gh（bootstrap 自举，走 api.github.com 查询 gh/git 二进制包）
- 建立方案 `docs\plans\0001-env-deps.md`：环境依赖管理（gh/git 自举安装到 `D:\ohmyenv`）
- 实现 `scripts\ohmyenv.ps1` CLI：query / deploy / install / update / lock / status，全部通过 api.github.com 查询下载（不依赖已装 gh）
- 建立 `scripts\env.psd1` 锁定清单（版本 + sha256 回填）
- gh/git 正式移交本项目管理：安装在 `D:\ohmyenv\gh`、`D:\ohmyenv\git`，旧文件改名保留（`*.removed-20260819`）
- 建立研究文档 `docs\research\gh-git-https-ssh.md`：HTTPS / SSH 互相配置指南（含本机实测状态与待办）
- 初始化 git 仓库（`main` 分支，根提交 `077e6b4`，含 `.gitignore`）
- 密钥管理：age 1.3.1、sops 3.13.3 接入 `ohmyenv` CLI（新增 `zip` 单目录展平与单文件 `copy` 解压类型）
- 生成 age 密钥（`%APPDATA%\sops\age\keys.txt`），设置 `SOPS_AGE_KEY_FILE`，建立 `.sops.yaml` 与 `scripts\sops-test.ps1` 冒烟测试
- 建立方案 `docs\plans\0002-codex-takeover.md`：Codex 二进制与 DeepSeek 密钥管理接管（评审中）

### Changed

- 版本管理重构：`New-ToolDef` 不再硬编码版本；`env.psd1` 为唯一 pin 来源，新增 `pin` 命令（`lock` 为别名），流程改为“先 pin 后 update”
- 下载通道：aria2（`D:\ohmyenv\aria2` 1.37.0）多线程优先，curl / Invoke-WebRequest 兜底
- Codex 接管落地：0.148.0 原生二进制（`D:\ohmyenv\codex`，SHA256SUMS 校验 + targz 解压），npm 版保留双轨共存
- 沙箱永久关闭：`sandbox_mode = "danger-full-access"` + `approval_policy = "never"` 合并写入（未覆盖原配置）
- DeepSeek 密钥迁移：交互式设置用户级 `DEEPSEEK_API_KEY`（`scripts\set-deepseek-key.ps1`），`config.toml` 改用 `env_key`，明文清除
- 7-Zip 接管：26.02 部署到 `D:\ohmyenv\7z`，新增 `7z-archive` 解压类型（Windows tar 直接解包，无需预装 7z），omc 注册表移除并改名保留旧文件
- 交接确认脚本 `scripts\verify-codex-handover.ps1`：新终端一键验证 codex 解析到原生版（PASS/FAIL）
- Codex 交接完成：npm `@openai/codex` 已卸载，shim 清除；doctor 确认 `managed by npm: no`、`update action: manual`（更新只走 ohmyenv）
- DeepSeek key 的 SOPS 加密副本：`.secrets\deepseek.env.enc`（可提交），新增 `scripts\sops-encrypt-deepseek.ps1` 一键加密/回读验证；明文不入库（`.gitignore` 保护）
- Codex 安装后增强配置功能：独立脚本 `scripts\set-codex-statusline.ps1` 幂等合并 `[tui]` 状态栏（`model-with-reasoning` / `git-branch` / `context-remaining`，彩色开关 `-NoColors`），不覆盖 DeepSeek/沙箱/信任项目等既有配置；`codex doctor` 确认 `config.toml parse ok`
- 建立研究文档 `docs\research\gh-cli.md`：gh 2.91.0 本机现状（认证/scopes/配置）、API 限流兜底通道、命令能力地图、与 ohmyenv 衔接及按需特性建议
- 文档规范扩展（AGENTS.md 规则 3）：`docs\research\` 研究文档纳入四块文档体系，`docs\README.md` 更新文档地图、命名约定与研究文档索引
- 状态栏升级为专业组合（对照 0.148.0 源码核实全量可选项）：`run-state` + `model-with-reasoning` + `git-branch` + `branch-changes` + `context-remaining` + `used-tokens` + `permissions`，主题色按类别区分（青/绿/品红）；`scripts\set-codex-statusline.ps1` 默认值同步更新
- 建立研究文档 `docs\research\codex-statusline.md`：状态栏可选项全量清单（官方描述 + 渲染示例）、样式机制（` · ` 分隔符、主题色 accent）、`/statusline` 交互行为、推荐配置与注意事项
- 状态栏补回项目目录显示：`current-dir`（当前工作目录完整路径）加入默认组合，与 `git-branch` / `branch-changes` 一并置于状态栏最后（`… · danger-full-access · D:\ohmypwsh · main · +12 -3`），`run-state` + `model-with-reasoning` + 用量/权限在前；`scripts\set-codex-statusline.ps1` 默认值与已应用配置同步更新
- 分隔符研究（gh 源码核实）：` · ` 为硬编码常量 `STATUS_LINE_SEPARATOR`，`[tui]` 无 separator 配置键，未知状态栏项被静默忽略，无法改用 `|`；结论已沉淀进 `docs\research\codex-statusline.md`
- 目录与分类规范（AGENTS.md 新增章节）：脚本 / 文档 / 配置 / 密钥数据 / 环境目录五类物理分离，新增文件必须归入对应目录（参考 `D:\hyper-v-lab` 的 AGENTS.md 风格），`docs\README.md` 增加指引
- 项目目录与文件索引：`docs\README.md` 新增完整目录树（根文件 / `.secrets` / `docs` / `scripts` 逐文件说明）与外部环境目录说明，AGENTS.md 分类要点指向该索引
- 建立对标研究 `docs\research\agents-docs-benchmark.md`：用 gh 调研 agentsmd 开放格式 / openai-agents-python / codex / zed 的 AGENTS.md 与文档结构，结论：本仓五要素齐全已属前列，建议补常用命令节、提交约定成文、根 README（待确认）
- 对标研究三项建议落地：AGENTS.md 新增「常用命令」（ohmyenv 全家 + PATH 重建 + 日常脚本）与「提交约定」（feat/docs/fix/chore 前缀）；根目录新增 `README.md` 项目入口；`docs\README.md` 目录索引同步

### Fixed

- `Get-InstalledVersion` 数组展开 bug（`@versionArgs` 解析异常导致所有工具显示未安装）
- 7z 版本解析（首行为空行）
- `Get-EnvLock` 静态元数据与锁文件同步（如 Extract 类型变更）
- `Invoke-GitHubApi` 全局兜底扩展到 5xx 网关错误（不限于 403 限流）

### Changed

- 按研究文档补齐本机配置：`gh auth setup-git`（HTTPS 走 gh 凭据助手）、ssh-agent 启用并加载密钥、`~/.ssh/config` 增加 github.com 条目、gh token 增加 `admin:public_key` scope
- 用户 PATH：移除 `D:\Oh-My-Claude\.envs\base\git\cmd`，前置注册 `D:\ohmyenv\gh\bin`、`D:\ohmyenv\git\cmd`
- omc 注册表移除 gh/git（`$BaseTools` 只保留 7z / aria2）
- GitForWindows 注册表与 `CLAUDE_CODE_GIT_BASH_PATH` 指向 `D:\ohmyenv` 的新安装
