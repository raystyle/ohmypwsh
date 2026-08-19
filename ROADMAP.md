# ROADMAP

项目阶段与里程碑。状态：`未开始` / `进行中` / `已完成` / `挂起`。

## 阶段总览

| 阶段 | 目标 | 状态 |
| --- | --- | --- |
| 0 | 项目基础设施：AGENTS 规则、文档规范 | 已完成 |
| 1 | 环境依赖管理：独立 D 盘环境目录，自建 gh/git 安装管理 | 已完成 |
| 2 | 密钥管理：age + SOPS 接入 ohmyenv，.sops.yaml 与冒烟测试 | 已完成 |
| 3 | Codex 接管：原生二进制 + 沙箱 + DeepSeek 密钥迁移到 env_key | 已完成 |
| 4 | 项目核心目标 | 未开始（待用户定义） |

## 阶段 0：项目基础设施（已完成）

- 建立 AGENTS.md 规则 1（踩坑当场沉淀）、规则 2（环境感知，默认 pwsh）、规则 3（文档规范）
- 建立 CHANGELOG / ROADMAP / `docs\plans\` 文档骨架

## 阶段 1：环境依赖管理（已完成）

目标：参考 D:\Oh-My-Claude 的 omc 机制，在 D 盘独立系统环境目录（`D:\ohmyenv`）安装 gh 与 git，并在项目内沉淀安装管理脚本（`scripts\`），随后清理旧安装。

方案：`docs\plans\0001-env-deps.md`（bootstrap 不依赖 gh，通过 api.github.com 查询二进制包）。

完成项：

- `scripts\ohmyenv.ps1` CLI（query / deploy / install / update / lock / status）+ `scripts\env.psd1` 锁定清单
- gh 2.91.0、git 2.54.0.windows.1 安装于 `D:\ohmyenv`，版本与 sha256 已锁定
- omc 注册表移除 gh/git；旧文件改名保留（`*.removed-20260819`），确认无误后可删除
- 用户 PATH 前置新目录、移除旧 git 路径；gh 登录状态正常（keyring）

## 阶段 2：密钥管理（已完成）

- age 1.3.1、sops 3.13.3 接入 `ohmyenv`（查询/下载/锁定/sha256/PATH 统一管理）
- 生成 age 私钥 `%APPDATA%\sops\age\keys.txt`，设置 `SOPS_AGE_KEY_FILE` 用户环境变量
- 建立 `.sops.yaml`（公钥）与 `scripts\sops-test.ps1` 冒烟测试（已通过）

## 阶段 3：Codex 接管（已完成）

- 方案：`docs\plans\0002-codex-takeover.md`
- 二进制：npm 包（0.147.0）→ ohmyenv 原生（0.148.0，`D:\ohmyenv\codex`）
- 沙箱：`sandbox_mode=danger-full-access` + `approval_policy=never`（合并写入，已生效）
- 密钥：`experimental_bearer_token` 明文 → `DEEPSEEK_API_KEY` 用户环境变量 + `env_key`（已生效，SOPS 加密副本见下）
- 已完成：原生部署、doctor 验证、aria2 下载通道（7.1MiB/s）
- 已完成：npm 交接清理（`@openai/codex` 卸载、shim 清除、doctor 确认单一原生来源）
- 已完成：7zip 接管（`D:\ohmyenv\7z` 26.02，omc 已移除，`7z-archive` 用 tar 解包）
- 已完成：DeepSeek key SOPS 加密副本（`.secrets\deepseek.env.enc`，换机/轮换可恢复）
- 已完成：状态栏增强配置（`[tui] status_line` 独立脚本 `scripts\set-codex-statusline.ps1` 幂等合并，`codex doctor` 验证 parse ok）
