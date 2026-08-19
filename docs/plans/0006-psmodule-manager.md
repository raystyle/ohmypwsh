# 0006-psmodule-manager — PowerShell 模块管理器（在线/离线、PS5/PS7）

- 状态：已完成
- 日期：2026-08-19
- 关联：ROADMAP 阶段 4、`docs\research\omc-psmodule-management.md`

## 背景与问题

- 本机 PowerShell 模块已恢复系统原生（PS5.1 / PS7 干净）；但日常与未来需要安装第三方模块、自研封装模块，且要支持 PS5 与 PS7 双兼容
- omc 的模块管理（本地 nupkg 仓库 + WebClient 直连 + 无校验拷贝 + 锁散落 + 仓库注册残留）有可取处也有坑；研究结论：本地缓存 + 先 lock 后 install + 共享目录优先 + 现代命令（PSResourceGet）
- 需求：在线（PSGallery）与离线（本地 nupkg / 自研模块包）都兼容；PS5/PS7 都能用

## 目标与非目标

- 目标：
  - `scripts\psmodule.ps1` CLI：list / pin / install / update / uninstall / pack
  - 在线安装：PSGallery 解析版本 → nupkg 下载到 `D:\ohmyenv\cache\modules`（复用 aria2/curl 下载链）→ 本地部署
  - 离线安装：`-File <nupkg>` 直接部署（含自研模块包）；在线/离线同一部署路径
  - 自研模块：`pack` 用 `Compress-PSResource` 把模块目录封装成 nupkg
  - PS5/PS7：默认共享部署到 `D:\ohmyenv\modules` + 用户 PSModulePath 追加（两 shell 同见）；可按模块 Target 指定 PS5/PS7
  - 锁集中登记：`scripts\modules.psd1`（唯一 pin 来源，仿 env.psd1）；nupkg sha256 回填
- 非目标：不做全局 PSRepository 注册；不替代 PSGallery 官方通道；不强制 profile 集成（lock 可带可选 Profile 块）

## 方案

### 目录与锁定

- 部署根：`D:\ohmyenv\modules\<模块>\<版本>\`（Shared 默认，追加进用户 PSModulePath）
- 缓存：`D:\ohmyenv\cache\modules\<模块>.<版本>.nupkg`
- 锁定：`scripts\modules.psd1`（ModuleRoot + Modules@{ Name = @{ Version; Source; Package; Sha256; Target } }）

### CLI（psmodule.ps1）

| 命令 | 说明 |
| --- | --- |
| `list` | 锁定 vs 已安装（含 PS5/PS7 兼容提示） |
| `pin <模块> [-Version X \| -Latest]` | 写锁（不装） |
| `install <模块> [-Version X] [-File <nupkg>]` | 在线（PSGallery）/ 离线（本地包）安装 |
| `update <模块\|all>` | 更新到最新并重新锁（同主版本自动，跨主版本待确认） |
| `uninstall <模块>` | 删除版本目录与锁 |
| `pack <目录> [-Version X] [-Out <目录>]` | 封装自研模块为 nupkg |

### 安装流程（在线/离线同一部署路径）

1. 解析版本：`-Version` / 锁版本 / `Find-PSResource` 最新（在线）；离线直接用包内 manifest
2. 获取 nupkg：在线 → `Save-ReleaseAsset` 下载 PSGallery v2 包 URL 到 cache；离线 → `-File` 拷入 cache
3. 校验：解包临时目录，`Import-PowerShellDataFile` 读 psd1 → 模块名/版本；sha256 回填锁
4. 部署：解包（跳过 `_rels`/`package`/`[Content_Types].xml`/`PSGetModuleInfo.xml`）→ 目标目录
5. 写锁 + 确保 PSModulePath 条目；可选 Profile 标记块（`BEGIN/END ohmypwsh: <模块>`）

### 与其他组件衔接

- 复用 `helpers.ps1` 的 `Save-ReleaseAsset`（aria2/curl/IWR + sha256）
- 目录规范：`scripts\modules.psd1` 归「配置」（模块版本唯一 pin 来源），同步 docs/README 与 AGENTS

## 实施步骤

1. 环境卫生：5.1 PowerShellGet 1.0.0.1 → 2.2.5（CurrentUser，TLS 1.2）✓
2. omc 残留清理：注销 OhMyClaude 仓库（双 shell）、删 nupkg/锁文件/孤儿 psmodule.ps1 ✓
3. 方案文档（本文件）✓
4. `modules.psd1` + `psmodule.ps1`（list/pin/install/update/uninstall/pack）✓
5. 实测：pack 自研示例模块 → 离线安装 → 双 shell 验证 → uninstall；在线安装 Pester 5.7.1 → 双 shell 验证
6. 文档：CHANGELOG / ROADMAP / docs/README / AGENTS 常用命令

实测补充（编码坑，已沉淀为优先规则）：

- 自研模块 manifest 若 UTF-8 无 BOM 且含非 ASCII，PS5.1 按 ANSI（GBK）读取会解析失败 → 自研模块 manifest 必须 UTF-8 带 BOM（AGENTS 规则 4，见 `docs\research\powershell-encoding.md`）
- 在线安装 PSGallery 包无此问题（官方包 manifest 带 BOM）

## 风险与回滚

- PSGallery 直连不稳 → 复用 aria2/curl 下载链 + 缓存；离线包不受影响
- 二进制模块跨 .NET Framework / .NET 不兼容 → 默认 Shared 只保证可发现，加载失败按 Target 指定 PS5/PS7
- 部署目录损坏 → 删版本目录重装；锁 sha256 校验兜底

## 验收标准

- `list` 正确显示锁定与已安装版本
- 在线安装与 `-File` 离线安装均成功，pwsh7 与 powershell.exe 均可加载
- `pack` 产出 nupkg 可被 `install -File` 安装
- `modules.psd1` 为唯一锁来源，无全局 PSRepository 残留
