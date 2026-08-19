# 0007-uv-python-takeover — uv / Python 接管（uv 最新 + Python 3.12 为准）

- 状态：已完成
- 日期：2026-08-19
- 关联：ROADMAP 阶段 4

## 背景与问题

- uv + Python 由 omc 的 `base\uv.ps1` 管理：uv 0.11.8 在 `.envs\base\bin\uv.exe`，Python 3.14.4 由 uv 装入 `.envs\base\uv-python`，ruff/ty/jupyter 依赖该 python 与 `uv` 命令
- omc 用一组 `UV_*` 用户环境变量把缓存/工具/python 目录指向 `.envs\base\...`；pip/uv 镜像走 `%APPDATA%\pip\pip.ini` 与 `%APPDATA%\uv\uv.toml`（aliyun）
- 需求：uv/python 由 ohmyenv 接管——uv 最新版，Python 以 **3.12** 为准；源（镜像）与 uv 缓存等环境变量重新配置并确认
- 范围外：jupyter / ruff / ty 暂不动（先不管，保留 omc 侧现场）

## 目标与非目标

- 目标：
  - ohmyenv 新增 `uv`（astral-sh/uv，最新版）与 `python`（astral-sh/python-build-standalone，**3.12 线 install_only**）工具，pin + deploy 到 `D:\ohmyenv`
  - `UV_*` 用户环境变量重指向 `D:\ohmyenv`（cache / python / tools / install dir）；pip 与 uv 镜像源确认保留 aliyun
  - omc 注册移除 uv（`$BaseScripts`、`uv.ps1`、`uv.exe` 改名保留）
- 非目标：不动 jupyter/ruff/ty 与 omc 的 `.envs\base\uv-python`；不删除 omc 的 python shim（jupyter 依赖）

## 方案

### 工具定义

- `uv`：`zip` 展平，版本解析 `uv (\d+\.\d+\.\d+)`
- `python`：资产固定匹配 `cpython-3.12.*-x86_64-pc-windows-msvc-install_only.tar.gz`，新增静态 `VersionPattern`（从资产名提取版本，因 python-build-standalone 的 tag 是日期而非版本）
- `Resolve-ToolVersion` 支持 `VersionPattern`：命中资产名则用捕获组作版本，否则沿用 tag 前缀逻辑

### 环境变量（用户级，重指向 ohmyenv）

| 变量 | 值 |
| --- | --- |
| `UV_CACHE_DIR` | `D:\ohmyenv\uv-cache` |
| `UV_PYTHON_INSTALL_DIR` | `D:\ohmyenv\python` |
| `UV_PYTHON_BIN_DIR` | `D:\ohmyenv\python` |
| `UV_PYTHON_INSTALL_MIRROR` | 保留 nju python-build-standalone 镜像 |
| `UV_TOOL_DIR` | `D:\ohmyenv\uv-tools` |
| `UV_TOOL_BIN_DIR` | `D:\ohmyenv\uv-tools\bin` |
| `UV_INSTALL_DIR` | `D:\ohmyenv\uv` |

### 源（确认保留）

- pip：`%APPDATA%\pip\pip.ini` → aliyun（确认存在）
- uv：`%APPDATA%\uv\uv.toml` → aliyun 默认 index（确认存在）

### omc 移除

- `omc.ps1` `$BaseScripts` 移除 `uv`；`.scripts\base\uv.ps1`、`.envs\base\bin\uv.exe` 改名 `*.removed-20260819`；CLAUDE.md 同步
- PATH 前置 `D:\ohmyenv\uv`、`D:\ohmyenv\python`、`D:\ohmyenv\python\Scripts`、`D:\ohmyenv\uv-tools\bin`

## 实施步骤

1. helpers.ps1 / ohmyenv.ps1：uv/python 工具定义 + VersionPattern + ValidateSet ✓
2. `pin uv -Latest` + `deploy uv` ✓
3. `pin python -Latest` + `deploy python`（3.12 线 install_only）✓
4. `UV_*` 用户环境变量重指向 + PATH 前置 ✓
5. 源确认：pip.ini / uv.toml（aliyun）✓
6. omc 移除 uv（注册/脚本/二进制改名保留）✓
7. 验证：uv/python 解析到 D:\ohmyenv、版本正确、claude 仍可用
8. 文档：CHANGELOG / ROADMAP / README / docs/README / 踩坑沉淀

实测补充：

- python-build-standalone 的 install_only tarball 顶层套单目录（`python/`），`targz` 解压已加与 zip 相同的单目录展平
- `Resolve-ToolVersion` 新增 `VersionPattern`：python 的 tag 是日期（20260814），版本从资产名提取（3.12.14）
- 实测：uv 0.12.5、python 3.12.14 解析到 D:\ohmyenv；`uv python list` 识别 D:\ohmyenv\python；claude 2.1.187 正常

## 风险与回滚

- claude/jupyter 依赖 uv → 改 PATH 后仍解析到新 uv（jupyter 先不管，保留现场）；claude.exe 已装不受影响
- python 3.12 与 omc 3.14 并存 → omc 侧 uv-python 保留；uv 默认 python 由 `UV_PYTHON_INSTALL_DIR` 决定
- python-build-standalone tag 为日期 → 回滚用 `pin python -Tag <日期>` 重部署

## 验收标准

- `ohmyenv status` 显示 uv/python locked=installed=path=True
- `uv --version` 最新版；`python --version` = 3.12.x（`D:\ohmyenv\python`）
- `UV_*` 环境变量指向 `D:\ohmyenv`；pip/uv 镜像为 aliyun
- `claude --version` 正常；omc 不再注册 uv
