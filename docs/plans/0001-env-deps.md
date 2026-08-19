# 0001-env-deps — 环境依赖管理（gh/git 自举安装）

- 状态：已完成
- 日期：2026-08-19
- 关联：ROADMAP 阶段 1

## 背景与问题

项目需要 gh 与 git，但首次安装（bootstrap）阶段不能依赖已装好的 gh（先有鸡还是先有蛋）。因此初始环境构建必须直接依赖 `api.github.com`：通过 REST API 查询 gh/git 的发布资产，再直连下载二进制包。

现状：gh/git 来自 D:\Oh-My-Claude 的 omc 环境（用户级 PATH 暴露），需要迁出到 D 盘独立系统环境目录，并在项目内沉淀安装管理脚本。

## 目标与非目标

- 目标：
  - 独立环境目录 `D:\ohmyenv`，与项目解耦
  - 项目内沉淀安装管理脚本（`scripts\`）：查询、下载、校验、解压、PATH 管理
  - bootstrap 全程不依赖已有 gh，只靠 api.github.com + 直连下载
  - 版本锁定（gh / git 固定版本）
  - 清理旧安装（可恢复：先改名不删除）
- 非目标：暂不管理 Python / Node 等其他运行时；不做通用包管理器

## 方案

### 环境目录

```
D:\ohmyenv\
  gh\bin\gh.exe      # gh 2.91.0
  git\cmd\git.exe    # Git for Windows 2.54.0.windows.1
  cache\             # 下载缓存 + sha256 校验
```

### bootstrap 下载流程（不依赖 gh）

1. 按锁定 tag 查询 `api.github.com`：

   ```powershell
   $h = @{ 'User-Agent' = 'ohmypwsh-bootstrap'; 'Accept' = 'application/vnd.github+json' }
   Invoke-RestMethod -Uri 'https://api.github.com/repos/cli/cli/releases/tags/v2.91.0' -Headers $h
   ```

2. 从 `assets` 中按资产名匹配，取 `browser_download_url`
3. 用 `curl.exe`（或 Invoke-WebRequest）直连下载到 `cache\`
4. 失败重试（指数退避）；兜底：`browser_download_url` 模式固定，可直接拼直连 URL（302 重定向到 CDN）

实测（2026-08-19 验证通过）：

| 工具 | tag | 资产 | 大小 |
| --- | --- | --- | --- |
| gh | v2.91.0 | `gh_2.91.0_windows_amd64.zip` | 14,455,226 B |
| git | v2.54.0.windows.1 | `PortableGit-2.54.0-64-bit.7z.exe` | 58,995,352 B |

最新版查询：`GET /repos/<owner>/<repo>/releases/latest`（实测 gh v2.97.0、git v2.55.0.windows.4）。

已知坑（规则 1，当场沉淀）：

- api.github.com 未认证限流 60 次/小时，必须带 `User-Agent` 头
- 实测偶发 `EOF / 0 bytes` 与超时 → 下载与查询都必须有重试和兜底

### 安装

- gh：`Expand-Archive` 解压 zip → `D:\ohmyenv\gh\bin\gh.exe`
- git：PortableGit 是 7z 自解压包，直接 `PortableGit-2.54.0-64-bit.7z.exe -o<目标目录> -y` 解压，无需预装 7z

### PATH

- 用户 PATH 幂等加入：`D:\ohmyenv\gh\bin`、`D:\ohmyenv\git\cmd`
- 移除旧 PATH 条目：`D:\Oh-My-Claude\.envs\base\git\cmd`
- 保留 `D:\Oh-My-Claude\.envs\base\bin`（uv / python / aria2 等仍在使用）

### 清理（可恢复）

- `D:\Oh-My-Claude\.envs\base\git` → 改名为 `git.removed-YYYYMMDD`
- `D:\Oh-My-Claude\.envs\base\bin\gh.exe` → 改名为 `gh.exe.removed-YYYYMMDD`
- 待确认：是否同时从 omc 注册表（`.scripts\omc.ps1` 的 `$BaseTools`、`base\gh.ps1` / `git.ps1`）移除 gh/git，防止 `omc install/update` 重新装回

## 版本锁定

| 工具 | 锁定版本 | 资产 |
| --- | --- | --- |
| gh | 2.91.0 | `gh_2.91.0_windows_amd64.zip` |
| git | 2.54.0.windows.1 | `PortableGit-2.54.0-64-bit.7z.exe` |

安装完成后将 sha256 回填到 `scripts\env.psd1`，作为缓存校验依据。

## 备选方案

- 用现有 gh 下载资产：快，但 bootstrap 无法自举 → 仅作为 gh 已安装后的加速通道
- 国内镜像 / ghproxy：仅作为直连失败的兜底，优先级最低

## 实施步骤

1. 创建 `D:\ohmyenv\`（gh / git / cache）
2. 编写 `scripts\env.psd1`、`scripts\helpers.ps1`、`scripts\install-env.ps1`
3. 执行安装，验证 `gh --version` / `git --version` 为锁定版本
4. 回填 sha256，更新 PATH
5. 清理旧安装（改名），移除旧 PATH 条目
6. 确认 omc 注册表清理范围后执行

## 风险与回滚

- api.github.com 抖动 / 限流 → 查询与下载带重试，直连 URL 兜底；锁定版本减少查询次数
- 下载中断 → 缓存到 `cache\`，sha256 校验后重试
- 解压失败 → 删除残档重新解压
- 回滚：新环境异常时切回旧 PATH 即可；旧文件仅改名未删除，可随时还原

## 验收标准

- 在干净目录/环境下，仅运行项目脚本即可装好 gh/git，全程不依赖已有 gh
- `gh --version` 输出 2.91.0，`git --version` 输出 2.54.0.windows.1
- 用户 PATH 只含新目录，无 D:\Oh-My-Claude 残留 git 路径
- `scripts\env.psd1` 中 sha256 与缓存一致

## 实施结果（2026-08-19）

- CLI：`scripts\ohmyenv.ps1`（helpers：`scripts\helpers.ps1`；锁定清单：`scripts\env.psd1`）
- 安装结果：gh 2.91.0 @ `D:\ohmyenv\gh\bin\gh.exe`，git 2.54.0.windows.1 @ `D:\ohmyenv\git\cmd\git.exe`，sha256 均已回填
- 交接清理：omc 注册表移除 gh/git；旧文件改名 `*.removed-20260819` 保留（确认后可删除）；GitForWindows 注册表与 `CLAUDE_CODE_GIT_BASH_PATH` 已指向新安装
- PATH：前置 `D:\ohmyenv\gh\bin`、`D:\ohmyenv\git\cmd`，移除 `D:\Oh-My-Claude\.envs\base\git\cmd`；模拟新 shell 解析正确
- gh 登录：✓（keyring，scope：gist / read:org / repo / workflow）

已知坑（规则 1 沉淀）：

- PortableGit 7z 自解压：`<sfx>.exe -y -o<目标目录>`，无需预装 7z
- 安装流程被中断时，sha256 回填与锁定写入不会落盘；重跑 `install` 会命中缓存补齐
- omc 对 gh/git 的引用分散在 `omc.ps1`（注册表 + 安装顺序 + PATH 循环）与 `claude.ps1`（git bash 路径），清理时必须一并修改
