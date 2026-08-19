# gh（GitHub CLI）研究

> 2026-08-19 本机实测采集（gh 2.91.0，由 `ohmyenv` 管理）。配套文档：`docs\research\gh-git-https-ssh.md`（HTTPS/SSH 配置）。

## 一、现状（本机）

| 项目 | 值 |
| --- | --- |
| 版本 | 2.91.0（2026-04-22 发布） |
| 安装位置 | `D:\ohmyenv\gh`（ohmyenv 管理，`scripts\env.psd1` pin v2.91.0 + sha256） |
| PATH | `D:\ohmyenv\gh\bin`（用户 PATH 前置） |
| 认证 | github.com，账号 raystyle，keyring 存储，active |
| 默认协议 | `git_protocol=https`（HTTPS 走 gh 凭据助手） |
| Token scopes | `admin:public_key`、`gist`、`read:org`、`repo`、`workflow` |
| 扩展 | 无 |
| 别名 | `co` → `pr checkout` |
| 配置文件 | `%APPDATA%\GitHub CLI\config.yml`（键见下方）；`%APPDATA%\GitHub CLI\hosts.yml`（含 token，已掩码） |

`gh config list` 当前值：

```text
git_protocol=https  editor=  prompt=enabled  prefer_editor_prompt=disabled
pager=  http_unix_socket=  browser=  color_labels=disabled
accessible_colors=disabled  accessible_prompter=disabled
spinner=enabled  telemetry=enabled
```

## 二、API 通道与限流（兜底设计）

- api.github.com 匿名限流：60 次/小时/IP
- `gh api` 认证通道：5000 次/小时（实测 `remaining=5000`）
- 项目设计原则：bootstrap 阶段不依赖 gh（直连 api.github.com + User-Agent + 失败重试）；gh 安装后作为加速/兜底通道，`Invoke-GitHubApi` 在 403/5xx 时自动切 `gh api`

## 三、能力面（命令地图，v2.91）

Core：

```text
auth（认证）  browse（浏览器打开）  codespace  gist  issue  org
pr  project（Projects）  release（发布/资产）  repo  skill（agent skills，preview）
```

GitHub Actions：

```text
cache（Actions 缓存）  run（工作流运行）  workflow（工作流）
```

其他：`api`（统一 REST 通道）、`alias`、`attestation`（工件签名验证）、`completion`、`config`、`copilot`（preview）、`extension`、`gpg-key`、`label`、`licenses`、`preview`、`ruleset`（仓库规则）、`search`、`secret`、`ssh-key`、`status`（跨仓库聚合 issues/PRs/通知）、`variable`。

本项目已用到的关键命令：

```powershell
gh api rate_limit                     # 限流余量检查（兜底通道前提）
gh api repos/<owner>/<repo>/...      # releases / contents / trees 等元数据与原始内容
gh auth setup-git                     # 配置 git 使用 gh 凭据助手（HTTPS）
gh config set git_protocol https      # 强制协议
gh auth status                        # 认证与 scopes 巡检
```

## 四、与 ohmyenv 的衔接

- 版本管理：`ohmyenv pin gh [-Latest | -Version X]` 先 pin，`ohmyenv update gh` 升级并重新 pin（版本不硬编码）
- bootstrap 自举：首次安装/恢复环境不依赖已装 gh，走 api.github.com 直连下载
- 限流兜底：`Invoke-GitHubApi` 统一入口，403/5xx 自动切 `gh api`
- git 协议：本机 HTTPS + gh 凭据助手（`git_protocol=https`），SSH 备用方案见 `gh-git-https-ssh.md`

## 五、值得关注的特性（按需启用）

- `gh skill`（agent skills，preview）：GitHub 侧技能生态，与 Codex 技能（`~/.codex/skills`）可形成对照，暂不引入
- `gh copilot`（preview）：Copilot CLI，按需评估
- `gh status`：一条命令聚合相关仓库的 issues / PRs / 通知，日常巡检好用
- `gh secret` / `gh variable`：Actions 密钥与变量管理，后续可配合 SOPS（`.secrets`）做 CI 密钥轮换
- `gh attestation` + `ruleset`：供应链签名验证与仓库规则，适合放开协作时启用
- `gh completion`：可写入 `$PROFILE` 获得 Tab 补全（当前未配置）

## 六、建议 / 待办

- `telemetry=enabled` 当前开启：在意隐私可 `gh config set telemetry disabled`
- token scopes 现状够用（repo + workflow + admin:public_key + gist + read:org）；如需管理组织级 secret 再评估补 scope
- 别名只有 `co`：常用组合（如 `gh pr create --fill`、`gh repo view`）可按习惯加 alias
- 扩展为空：`gh extension install` 按需安装，避免引入过多外部插件
