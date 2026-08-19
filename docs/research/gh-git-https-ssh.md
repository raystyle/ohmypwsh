# gh 与 git 的 HTTPS / SSH 互相配置（Windows 专业指南）

> 基于最新官方文档与实践整理，并已对照本机（2026-08-19）实测核验。
> 适用于 Windows 10/11、Git for Windows（自带 Git Credential Manager）与 gh CLI。

## 0. 本机实测状态（对照基线）

| 项目 | 现状 | 说明 |
| --- | --- | --- |
| gh | 2.91.0，已登录（keyring） | token scope：admin:public_key / gist / read:org / repo / workflow |
| gh 协议 | `git_protocol = https` | `gh config get git_protocol` |
| gh 凭据助手 | 已配置 | `gh auth setup-git` 已执行（github.com / gist.github.com） |
| git 全局 | user.name / user.email / safe.directory / push.autosetupremote | 无 url 改写 |
| git 系统凭据 | `credential.helper = helper-selector` | 来自 PortableGit `etc\gitconfig`；GCM 随 Git for Windows 自带（`mingw64\bin`） |
| helper 可解析性 | 已验证 | pwsh 的 PATH 不含 `mingw64\bin` 时，git 仍能找到 `credential-helper-selector` |
| SSH | Windows OpenSSH 9.5p2，`id_ed25519` 已存在并已注册 | `ssh -T git@github.com` 认证成功 |
| ssh-agent | 服务 Running / Automatic，已 `ssh-add id_ed25519` | 免密生效 |
| SSH 配置 | `~/.ssh/config` 已加 github.com 条目 | IdentityFile + IdentitiesOnly |
| 环境变量 | GIT_SSH / GIT_SSH_COMMAND / core.sshCommand 均未设置 | git 使用自身默认 ssh |

## 1. 前置准备

- 安装 Git for Windows：建议选择
  - SSH executable → Use external OpenSSH
  - HTTPS backend → Use the native Windows Secure Channel library
  - Credential helper → Git Credential Manager
- 安装 gh：`winget install --id GitHub.cli` 或官网下载（本项目由 `scripts\ohmyenv.ps1` 管理）
- 确保 OpenSSH 客户端已启用（Windows 10/11 默认支持）

## 2. 使用 gh CLI 配置协议（推荐统一入口）

在 PowerShell / Git Bash 中执行：

```powershell
gh auth login
```

按提示选择：GitHub.com → 协议（HTTPS 推荐大多数场景，或 SSH）→ 浏览器登录。

选择 HTTPS 后执行：

```powershell
gh auth setup-git
```

自动配置 Git 使用 gh 作为凭据助手（凭证安全存储在 Windows Credential Manager）。

查看与设置协议：

```powershell
gh config get git_protocol
gh auth status
gh config set git_protocol https   # 或 ssh
```

> 坑（本机验证）：gh 2.91.0 不支持 `gh auth setup-git --check`（unknown flag）。
> 验证是否已配置，改用：
>
> ```powershell
> git config --global --get-regexp '^credential'
> ```
>
> 应看到类似 `credential.https://github.com.helper` 指向 gh。

## 3. 单个仓库切换 HTTPS ↔ SSH

```powershell
git remote -v

# 切到 HTTPS
git remote set-url origin https://github.com/用户名/仓库名.git

# 切到 SSH
git remote set-url origin git@github.com:用户名/仓库名.git

git remote -v
```

## 4. 全局强制重写（一次配置全部生效）

强制所有 GitHub 操作使用 HTTPS（即使 remote 是 SSH）：

```powershell
git config --global url."https://github.com/".insteadOf git@github.com:
git config --global url."https://github.com/".insteadOf ssh://git@github.com/
```

强制所有 GitHub 操作使用 SSH（即使 remote 是 HTTPS）：

```powershell
git config --global url."git@github.com:".insteadOf https://github.com/
```

查看：

```powershell
git config --global --get-regexp url
```

> 注意：全局重写会影响所有仓库；排查 remote 行为异常时先检查此项。

## 5. Windows 下 SSH 密钥完整配置（使用 SSH 时必需）

```powershell
# 1. 确保 .ssh 目录存在
mkdir $env:USERPROFILE\.ssh -Force

# 2. 生成 Ed25519 密钥（推荐），可设置 passphrase
ssh-keygen -t ed25519 -C "your_email@example.com"

# 3. 启动并设置 ssh-agent 开机自启（管理员）
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent

# 4. 添加密钥到 Agent
ssh-add $env:USERPROFILE\.ssh\id_ed25519

# 5. 复制公钥到剪贴板
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | Set-Clipboard
```

然后打开 GitHub → Settings → SSH and GPG keys → New SSH key，粘贴公钥；或用 gh 上传：

```powershell
gh ssh-key add $env:USERPROFILE\.ssh\id_ed25519.pub --title "windows-pwsh"
```

> 坑：`gh ssh-key add` 走 API，需要 `admin:public_key` scope。当前 token 没有，
> 先执行 `gh auth refresh -h github.com -s admin:public_key`。

测试连接：

```powershell
ssh -T git@github.com
# 成功: Hi 用户名! You've successfully authenticated...
```

可选 `~/.ssh/config`（`C:\Users\你的用户名\.ssh\config`）：

```text
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

防火墙限制端口 22 时，可强制走 443：

```text
Host github.com
    Hostname ssh.github.com
    Port 443
    User git
```

让 Git 强制使用 Windows 系统 OpenSSH（避免与 Git for Windows 自带 ssh 冲突）：

```powershell
git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
```

## 6. HTTPS 凭证管理（Windows 特有）

- `gh auth login` + `gh auth setup-git` 最推荐：自动使用 Windows Credential Manager
- 手动使用 PAT 时，Git Credential Manager 会弹出图形界面引导登录
- 清除错误凭证：控制面板 → 用户账户 → 凭据管理器 → Windows 凭据 → 删除相关 GitHub 条目

## 7. 场景推荐

| 场景 | 推荐协议 | 说明 |
| --- | --- | --- |
| 个人开发机长期使用 | SSH | 免密、方便 |
| 公司电脑 / 共享环境 | HTTPS + gh | 不留下私钥 |
| 网络 / 防火墙限制 | HTTPS 或 SSH over 443 | 443 端口更稳定 |
| 与 GitHub Desktop 配合 | HTTPS | Desktop 对 HTTPS 支持更好 |
| 多账号 | SSH（不同 key + config）或 HTTPS（不同 PAT） | 更灵活 |

切换后测试：

```powershell
git fetch
git push
```

## 8. 本机补齐记录（2026-08-19 已完成）

1. `gh auth setup-git` ✓ — HTTPS 已走 gh 凭据助手（`credential.https://github.com.helper`）
2. ssh-agent ✓ — 服务设为 Automatic 并启动，`ssh-add id_ed25519` 成功（注：服务配置需管理员/UAC）
3. `~/.ssh/config` ✓ — 已增加 github.com 条目（IdentityFile + IdentitiesOnly）
4. `gh auth refresh -s admin:public_key` ✓ — 浏览器授权完成，scope 已含 admin:public_key
5. `git_protocol` — 保持 `https`（推荐默认）；如需切换：`gh config set git_protocol ssh`

端到端验证（全部通过）：

- `ssh -T git@github.com`（BatchMode，走 agent 免密）→ 认证成功
- `gh api user/keys` → 可列出已注册 SSH key（之前 404，缺 scope）
- HTTPS 凭据助手 → `git config --global --get-all credential.https://github.com.helper` 指向 gh

## 附：验证命令速查（规则 1 沉淀）

```powershell
gh auth status                                  # 登录状态 + scope
gh config get git_protocol                      # 当前协议
git config --global --get-regexp '^credential'  # gh 凭据助手是否生效
git config --global --get-regexp url            # 全局 URL 改写
ssh -T git@github.com                           # SSH 连通性
ssh-keygen -lf $env:USERPROFILE\.ssh\id_ed25519.pub   # 指纹
```
