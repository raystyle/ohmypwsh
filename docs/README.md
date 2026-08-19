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

## 研究文档

- `research\gh-cli.md`：gh（GitHub CLI）能力研究（版本/认证/API 兜底/命令地图/衔接建议）
- `research\gh-git-https-ssh.md`：gh 与 git 的 HTTPS / SSH 互相配置（Windows 指南 + 本机实测）
- `research\age-sops-key-management.md`：密钥管理（age + SOPS，接入 ohmyenv）
- `research\ohmyenv-pitfalls.md`：ohmyenv 踩坑沉淀
- `research\codex-deepseek-config.md`：Codex 接管记录（原生二进制 + 沙箱 + DeepSeek 密钥 + 状态栏）
