# 0010 项目本质重定位：可迁移 Agent 环境部署与管理模块 CLI

> 2026-08-20，用户重新定位项目本质。

## 定位

ohmypwsh 的本质不是「个人环境依赖管理脚本集」，而是一个 **Agent 环境部署与管理模块 CLI**：

从 Windows 原生 PowerShell 5.1 出发，一键完成「初始化 → 升级 PowerShell 7 → 部署完整
PowerShell 模块 CLI → 安装/管理工具与 agent 环境」，并且**所有已部署产物（含密钥）可以打包
压缩，在另一台 Windows 上通过产物压缩包一键还原环境**。

## 三条主链

1. **Bootstrap 链（起点，人类初始部署）**：关闭所有 PowerShell → `cmd` 启动 Windows 自带
   PS5.1 → `set-pwsh.ps1` 一键幂等安装/升级 pwsh7 → 之后切到 pwsh7 部署模块 CLI 与工具。
2. **管理链（日常）**：工具管理（ohmyenv）+ 模块管理（psmodule）+ agent 配置
   （codex/claude/kimi/statusline）+ 密钥管理（age/sops）。
3. **迁移链（换机）**：产物打包（EnvRoot + 模块 + 配置 + 密钥）→ 压缩包 → 目标机解包还原
   （重定位路径 + 注册 PATH/环境变量 + 恢复密钥）。

## 现状差距

- 入口脚本 `#Requires -Version 7.0`，原生 PS5.1 无法运行，bootstrap 缺起点。
- 脚本是散文件 + dot-source（`ohmyenv.ps1` → `helpers.ps1`），未收敛为可
  `Import-Module` 的模块。
- `EnvRoot` 硬编码 `D:\ohmyenv`（`env.psd1`、`helpers.ps1`、`psmodule.ps1`、
  `modules.psd1`、`set-claude-config.ps1` 等多处）。
- 项目根硬编码 `D:\ohmypwsh`（`set-claude-statusline.ps1` 的 statusLine command、
  `set-claude-config.ps1` 的 `$mainProject`）。
- pwsh7 本身未纳入工具管理（不随产物打包，换机无法由压缩包还原）。
- 无 pack/unpack 能力。

## 目标架构（三层）

```
Layer 0  bootstrap（PS5.1 原生入口）
  - bootstrap.ps1：仅依赖 Windows 自带 PS5.1 + .NET
  - 职责：装/升级 pwsh7 → 部署 ohmyenv 模块 → 注册 PATH → 之后切 pwsh7

Layer 1  omp PowerShell 模块（pwsh7，命令名 omp）
  - 工具：query/install/deploy/update/pin/status/daily（含 pwsh7 自身）
  - 模块：psmodule（在线/离线、PS5/PS7 共享部署）
  - agent：codex/claude/kimi/statusline/keys 配置幂等部署
  - 迁移：pack（打包）/ unpack（还原）

Layer 2  产物
  - EnvRoot：工具安装根（可重定位）
  - 配置：~/.codex、~/.claude、~/.kimi-code、starship、profile
  - 密钥：SOPS 加密副本（.secrets）+ age 私钥
```

## 产物分类：安装包 vs 部署包

产物包分两类，迁移与还原策略不同：

**安装包（installer）**：保留原始安装器，二次部署直接安装 + 配置，**不进入绿色 EnvRoot**。

| 工具 | 安装包 | 二次部署 |
| --- | --- | --- |
| pwsh7 | `PowerShell-7.6.5-win-x64.msi` | 静默安装到 Program Files |
| codex | `codex-package-*-windows-msvc.tar.gz` | 解压/安装到官方位置 |
| claude | `claude-agent-sdk` wheel | 官方安装/同步 native 位 |
| kimi | 官方 `install.ps1` | 安装到 `~/.kimi-code` |
| git | Git 安装器 | 安装到官方位置 |
| 7z | `7z*-x64.exe` | 安装到官方位置 |

**部署包（portable）**：不需要安装器，一个二进制 + 环境变量 PATH 部署即可，进入 EnvRoot。

| 工具 | 形式 |
| --- | --- |
| age / sops / jq / yq | 单 exe |
| gh / aria2 / uv / rg / rmux / starship | 绿色 zip 解压 exe |
| python | tar.gz 解压（3.12 线） |

判据：官方只给「单二进制 / 绿色压缩包」→ 部署包；官方是「安装器（msi/exe/installer）且装到
系统位置」→ 安装包。打包迁移时，安装包只归档原始 installer，部署包归档解压后的绿色产物。

## 离线部署包（deploy）

`D:\ohmyenv\deploy\` 专门维护 ohmyenv 打包产出的部署压缩包（不在 EnvRoot 之外散落）。

### pack 清单

`ohmyenv pack` 产出单个压缩包 `D:\ohmyenv\deploy\ohmyenv-deploy-<时间戳>.zip`：

```
manifest.json            # pin 清单（Version/Tag/Asset/Sha256）+ 产物分类
portable/                # 部署包类绿色产物（age/sops/gh/aria2/uv/python/rg/jq/yq/rmux/starship）
installers/              # 安装包类原始 installer（pwsh MSI / codex tar.gz / git / 7z extra.7z+7zr）
secrets/                 # SOPS 加密副本（.secrets/*.enc）+ age 私钥（keys.txt）
scripts/                 # ohmyenv 部署器本身（scripts/*.ps1 / *.psd1 / *.psm1）
```

密钥只带加密副本 + age 私钥，明文 API key 不进包；目标机用 age 解密 SOPS 恢复。

### unpack 幂等部署

`ohmyenv unpack <zip>`（或 `ohmyenv deploy-offline`）逐工具幂等：

1. 解压到临时目录，读 manifest。
2. 对每个工具检测目标机已装版本，与 pin 版本比较：
   - 已装且版本 >= pin → 跳过（**版本高不降级**）
   - 未装 → 部署
   - 已装且版本 < pin → 升级到 pin
3. 部署包类：解压 `portable/<tool>` → EnvRoot + 幂等注册用户 PATH。
4. 安装包类：从 `installers/` 运行 installer（msiexec / 官方安装器）。
5. 密钥：恢复 age 私钥到 `%APPDATA%\sops\age\keys.txt`、`.secrets/*.enc` 回仓；API key 由 SOPS
   解密后写入用户环境变量（不回显）。
6. 全部完成后 `ohmyenv status` 自检，幂等重跑结果一致。

## 关键决策

1. **PS5.1 是 bootstrap 唯一起点**：入口脚本禁用 `#Requires -Version 7.0` 与 pwsh7 专属语法；
   只做「pwsh7 安装 + 模块部署 + PATH 注册」，业务逻辑一律下沉到 pwsh7 模块。
2. **pwsh7 纳入工具清单但归「安装包」类**：本机锁定 `v7.6.5`（用户指定），保留
   `PowerShell-7.6.5-win-x64.msi` 安装包，二次部署直接静默安装配置，**不进入绿色 EnvRoot**
   （安装位置 `C:\Program Files\PowerShell\7`）。走统一 pin/sha 校验（`hashes.sha256`）。
3. **EnvRoot 参数化**：删除硬编码 `D:\ohmyenv`，改为「配置默认值 + 参数/环境变量覆盖」；
   所有 Bin/Exe/cache/tools 路径由 EnvRoot 推导；还原时按目标机重定位。
4. **脚本收敛为模块 `omp`**：PowerShell 7 模块 `omp.psm1` + `omp.psd1`，导出命令 `omp`
   （`Invoke-Omp` 函数 + `omp` 别名，用法 `omp status/pin/pack/unpack/...`），保留
   `ohmyenv.ps1` 薄入口做 bootstrap 前的直接调用；`helpers.ps1` 转为模块私有函数。
5. **产物打包迁移**：`ohmyenv pack` 产出单个压缩包，内容 = 部署包工具（EnvRoot 绿色产物）+
   安装包工具（原始 installer 归档）+ 模块 + 配置模板 + `.secrets` 加密副本 + age 私钥；
   `ohmyenv unpack` 在目标机解包 → 重定位 EnvRoot → 安装包重装配置 → 部署包注册 PATH →
   恢复密钥（SOPS 解密回读验证）。
6. **密钥迁移原则**：明文密钥/凭据永不进包；只带 age 私钥 + SOPS 加密副本，目标机用 age
   解密恢复；API key 环境变量由 SOPS 解密后重写，不在日志/终端回显。

## 实施路径

- **阶段 A 可重定位**：EnvRoot/项目根参数化，扫清硬编码；`ohmyenv status` 仍兼容默认
  `D:\ohmyenv` 运行。
- **阶段 B bootstrap 起点**：新增 PS5.1 兼容 `bootstrap.ps1`；pwsh7 纳入工具定义与
  pin/sha；bootstrap 只装 pwsh7 + 部署模块 + 注册 PATH。
- **阶段 C 模块化**：`ohmyenv.psm1`/`ohmyenv.psd1` 收敛现有命令；`set-*.ps1` 转为模块内
  agent 子命令（保留独立脚本兼容层）。
- **阶段 D 迁移**：`ohmyenv pack` / `ohmyenv unpack`；实测「本机打包 → 干净机器还原 →
  status/doctor/密钥解密全绿」。

## 验收标准

1. 干净 Windows（仅原生 PS5.1）跑 `bootstrap.ps1` 一键得到 pwsh7 + ohmyenv 模块。
2. `ohmyenv pack` 产出单个压缩包；换一台 Windows 解包后 `ohmyenv status`、`codex doctor`、
   `claude /status`、`kimi` 全部就绪，密钥可用且无明文泄漏。
3. EnvRoot 改到非 `D:\ohmyenv` 路径后全链路可运行（无硬编码报错）。
