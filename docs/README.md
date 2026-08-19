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

## 研究文档

- `research\gh-cli.md`：gh（GitHub CLI）能力研究（版本/认证/API 兜底/命令地图/衔接建议）
- `research\gh-git-https-ssh.md`：gh 与 git 的 HTTPS / SSH 互相配置（Windows 指南 + 本机实测）
- `research\age-sops-key-management.md`：密钥管理（age + SOPS，接入 ohmyenv）
- `research\ohmyenv-pitfalls.md`：ohmyenv 踩坑沉淀
- `research\codex-deepseek-config.md`：Codex 接管记录（原生二进制 + 沙箱 + DeepSeek 密钥 + 状态栏）
- `research\codex-statusline.md`：Codex TUI 状态栏研究（全量可选项 / 样式机制 / 推荐配置）

## 项目目录索引

```text
ohmypwsh/
├─ AGENTS.md                    协作规则（最高约束）：规则 1-3、目录分类、设计原则
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
│  │  └─ 0002-codex-takeover.md Codex 接管方案（原生二进制 + 沙箱 + 密钥）
│  └─ research\                 研究文档（工具能力 / 踩坑沉淀 / 实测记录）
│     ├─ gh-cli.md              gh CLI 研究（现状/认证/API 兜底/命令地图）
│     ├─ gh-git-https-ssh.md    gh 与 git 的 HTTPS/SSH 互相配置（本机实测）
│     ├─ age-sops-key-management.md  密钥管理（age + SOPS 接入 ohmyenv）
│     ├─ ohmyenv-pitfalls.md    ohmyenv 踩坑沉淀
│     ├─ codex-deepseek-config.md    Codex 接管记录（沙箱/密钥/状态栏）
│     └─ codex-statusline.md    Codex TUI 状态栏研究（全量可选项/样式/推荐配置）
│
└─ scripts\                     环境脚本（全部入口）
   ├─ ohmyenv.ps1               CLI：query / deploy / install / update / pin / status
   ├─ helpers.ps1               模块函数（下载、安装、Invoke-GitHubApi 限流兜底）
   ├─ env.psd1                  工具版本锁定清单（唯一 pin 来源，版本不硬编码）
   ├─ set-deepseek-key.ps1      DeepSeek API Key 交互式设置（用户级环境变量）
   ├─ set-codex-statusline.ps1  Codex 状态栏幂等合并（[tui] status_line）
   ├─ sops-encrypt-deepseek.ps1 SOPS 重加密/回读验证
   ├─ sops-test.ps1             SOPS 冒烟测试
   └─ verify-codex-handover.ps1 Codex 交接验证（原生版解析 PASS/FAIL）
```

外部环境目录（git 之外，由 ohmyenv 管理）：`D:\ohmyenv` —— gh / git / age / sops / codex / aria2 / 7z 安装根。

> 目录分类规则见 `AGENTS.md`「目录与分类规范」；本索引随文件增删同步维护。
