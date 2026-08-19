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

### Changed

- 按研究文档补齐本机配置：`gh auth setup-git`（HTTPS 走 gh 凭据助手）、ssh-agent 启用并加载密钥、`~/.ssh/config` 增加 github.com 条目、gh token 增加 `admin:public_key` scope
- 用户 PATH：移除 `D:\Oh-My-Claude\.envs\base\git\cmd`，前置注册 `D:\ohmyenv\gh\bin`、`D:\ohmyenv\git\cmd`
- omc 注册表移除 gh/git（`$BaseTools` 只保留 7z / aria2）
- GitForWindows 注册表与 `CLAUDE_CODE_GIT_BASH_PATH` 指向 `D:\ohmyenv` 的新安装
