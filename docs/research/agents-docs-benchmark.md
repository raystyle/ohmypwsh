# AGENTS.md / 文档 / 项目结构对标研究（开源基准）

> 2026-08-19 用 gh 调研开源样本，评估本仓 `AGENTS.md` + `docs` + 项目结构是否已达最佳。

## 对标样本

| 仓库 | 特点 | 可借鉴点 |
| --- | --- | --- |
| [agentsmd/agents.md](https://github.com/agentsmd/agents.md)（23.7k★，官方开放格式） | AGENTS.md = “给 agent 的 README”，强调实用命令 | Dev 环境提示 / 测试指令 / PR 说明，全部是可执行命令，不要空泛原则 |
| [openai/openai-agents-python](https://github.com/openai/openai-agents-python) | 分层 AGENTS.md（310 行） | Contributor Guide（强制规则）→ Project Structure Guide（目录+重要文件）→ Operation Guide（开发流程/测试/提交）→ 文档验证分级 |
| [openai/codex](https://github.com/openai/codex) | 322 行贡献规范 | 代码评审规则、测试组织、变更规模上限（800 行） |
| [zed-industries/zed](https://github.com/zed-industries/zed) | 188 行 + Rules Hygiene | 新规则高门槛；明确“什么不该写进规则” |
| [cline/cline](https://github.com/cline/cline) | 32 行极简 | 小项目/单工具仓库可以极简 |

## 最佳实践提炼

1. **命令优先**：AGENTS.md 的核心价值是给出可直接执行的命令（agentsmd 主张），环境事实（路径/版本/账号）要写清（codex、hyper-v-lab 均有）
2. **规则少而硬，操作给流程**：强制规则要短、可验证；开发流程/提交/测试放 Operation 类章节（openai-agents-python）
3. **项目结构与重要文件索引**：目录分类 + 文件索引是 openai-agents-python Project Structure Guide 的核心，我们已具备（AGENTS.md 分类 + `docs\README.md` 索引）
4. **文档体系**：CHANGELOG + ROADMAP + 方案（≈ADR）+ 研究（≈explanation），对应 Diátaxis 的 reference / explanation 分层，已是主流工程实践
5. **规则卫生**：避免规则膨胀（zed），每条规则可执行、可验证；小项目最忌照抄大仓库的 300 行贡献规范

## 我们的现状 vs 基准

| 维度 | 现状 | 基准 | 结论 |
| --- | --- | --- | --- |
| 环境感知（pwsh/版本/路径） | 规则 2 已写 | codex / agentsmd 均有 | ✅ 已达标 |
| 踩坑当场沉淀 | 规则 1（scripts + docs\research） | agentsmd 命令沉淀 | ✅ 已达标 |
| 文档规范 | 规则 3：CHANGELOG/ROADMAP/plans/research | openai-agents-python | ✅ 已达标（比多数仓库完整） |
| 目录分类 + 文件索引 | AGENTS.md 五类 + docs\README 完整树 | Project Structure Guide | ✅ 已达标 |
| 常用命令入口 | 缺（命令散在脚本注释） | agentsmd 核心主张 | ⚠️ 建议补「常用命令」节 |
| 提交/验证约定 | 有 commit 习惯（feat:/docs:）未成文 | Operation Guide | ⚠️ 建议成文一句话 |
| 根 README.md | 无 | GitHub 通用惯例 | ⚠️ 建议补（一句话 + 入口链接） |
| 规则卫生 | 已较克制（4 节） | zed Rules Hygiene | ✅ 保持克制即可 |
| 验证脚本引用 | sops-test / verify-codex-handover 存在但未在 AGENTS 引用 | openai-agents-python 测试节 | ⚠️ 随常用命令一并引用 |

## 结论

- 结构已属开源项目前列：环境事实 + 强制规则 + 文档规范 + 目录分类 + 文件索引五要素齐全，多数大仓库的 AGENTS.md 只到“贡献规范”一级
- 建议补 3 项低成本高收益（2026-08-19 已应用）：
  1. ✅ AGENTS.md 新增「常用命令」节（ohmyenv 全家、sops、交接验证、PATH 重建）
  2. ✅ 提交约定成文（`feat:/docs:/fix:/chore:` 前缀 + 中文描述）
  3. ✅ 根目录新增 `README.md`（一句话定位 + 文档/脚本入口），`docs\README.md` 索引同步
- 不建议：照抄 openai 长 AGENTS.md（我们是小型个人工具项目，规则贵精不贵多）
