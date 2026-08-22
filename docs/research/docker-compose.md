# docker compose 插件接入（Windows CLI 插件发现机制 + 踩坑沉淀）

## 目标

把 Docker CLI 的 compose 插件纳入 `set-docker.ps1` 管理：官方资产下载 + sha256 校验、
部署到 EnvRoot（可重定位、随 pack 换机）、并解决 Windows `/bin` 外发现插件的机制问题。

## 现状与结论

- Windows 官方 static Docker 包（`docker-<version>.zip`）**不含 compose 插件**——zip 里只有
  `docker/docker.exe` + `docker/dockerd.exe`，比 Linux static 包精简，无 `cli-plugins`。
  compose 需单独从 `docker/compose` release 获取 `docker-compose-windows-x86_64.exe` 作为 CLI 插件。
- `set-docker.ps1` 只部署引擎二进制（`docker.exe`/`dockerd.exe`），此前不自带 compose。

## 部署方式（进入 set-docker.ps1）

1. 资产：`docker/compose` 最新 release（`v5.5.0`，资产 `docker-compose-windows-x86_64.exe` +
   官方 `docker-compose-windows-x86_64.exe.sha256`）。
2. 校验：官方 `.sha256`（单行 `<64位hex>  文件名`）用 `Assert-Sha256` 校验。
3. 落位：`EnvRoot\docker\cli-plugins\docker-compose.exe`。
4. 发现：`~/.docker/config.json` 的 `cliPluginsExtraDirs` 数组追加
   `D:\ohmyenv\docker\cli-plugins`（幂等，保留已有自定义组件）。

## 踩坑：docker CLI 不读 `DOCKER_CLI_PLUGINS_PATH` 环境变量 ⚠️

先入为主的坑：以为设了环境变量 `/bin` 就能找到插件。实测：

```powershell
$env:DOCKER_CLI_PLUGINS_PATH = 'D:\ohmyenv\docker\cli-plugins'
& 'D:\ohmyenv\docker\bin\docker.exe' compose version   # → docker: unknown command: docker compose
```

**docker CLI 根本没有 `DOCKER_CLI_PLUGINS_PATH` 环境变量机制**（那是误认，与 kubectl/git 等不同）。

官方插件发现优先级（`docker/cli` `cli-plugins/manager`，平台相关）：

1. CLI config 目录（`~/.docker`）下的 `cli-plugins`（即 `%USERPROFILE%\.docker\cli-plugins`）。
2. `~/.docker/config.json` 的 `cliPluginsExtraDirs`（用户配置的额外插件目录数组）。
3. 平台默认系统目录（Windows：`%ProgramData%\Docker\cli-plugins`、`%ProgramFiles%\Docker\cli-plugins`）。

Windows 插件候选文件必须带 `.exe` 后缀，且暴露 `docker-cli-plugin-metadata` 子命令产出合法 JSON。
更高优先级目录里的同名插件会遮蔽更低优先级目录。

**选择 `cliPluginsExtraDirs` 而非默认 `~/.docker/cli-plugins`**：默认目录在用户主分区、不进
EnvRoot，换机还原时随 pack 带不走；写在 config.json 指向 `D:\ohmyenv\docker\cli-plugins` 则
插件本体随 EnvRoot 打包，环境可整体平移。config.json 本身在用户目录、set-docker 幂等维护。

## 幂等与校验

- 插件已存在则跳过下载（缓存 `cache\docker-compose-<version>.exe` + `.sha256`）。
- `cliPluginsExtraDirs` 已含 EnvRoot 路径则不重复追加（`-contains` 判断）。
- 写 config.json 时过滤掉数组里的 `null`/空项（`@(hashtable['key'])` 在键不存在时会混入 `null`）。

## 实测（2026-08-22）

| 项 | 结果 |
| --- | --- |
| `docker compose version` | `Docker Compose version v5.5.0`，exit=0（不再 unknown command） |
| 部署路径 | `D:\ohmyenv\docker\cli-plugins\docker-compose.exe`（50317312 字节） |
| sha256 | 与官方 `.sha256` 一致（前缀 `51e1e61195f3`） |
| 幂等 | 重跑部署不重复追加 `cliPluginsExtraDirs`；config.json 保持单条有效路径 |
| 临时探测 | 放 `~/.docker/cli-plugins` 立即可用（默认发现位），印证机制；EnvRoot 方案同样生效 |
| 完整脚本提权验证 | `gsudo pwsh -File scripts\set-docker.ps1`：走「已就绪」幂等分支，`docker info` 显示 `Plugins: compose: Docker Compose v5.5.0 / Path: D:\ohmyenv\docker\cli-plugins\docker-compose.exe`（CLI 权威确认插件来源） |

> 注：`docker system info` 的 `Plugins` 段（Volume/Network 等）是**引擎插件**列表，与 CLI
> 插件的发现无关，不能用它判断 compose 是否被 CLI 识别。（正确看点是 `docker info` 里
> `Plugins:` 下的 `compose` 条目。）
