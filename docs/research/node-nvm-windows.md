# Node.js / npm 接管研究（nvm-windows）

> 2026-08-20，来源：coreybutler/nvm-windows README + GitHub Release 实测 + omc 现状。

## 关键结论：nvm-sh/nvm 不支持 Windows

用户给的 `nvm-sh/nvm` 是 Mac/Linux 专用（bash 脚本）。Windows 对应物是
**nvm-windows**（`coreybutler/nvm-windows`，Go 编写，微软/npm/Google 推荐的 Windows Node 版本
管理器）。两者哲学不同，不是克隆关系。

## nvm-windows 现状

- 最新 `v1.2.2`，资产：
  - `nvm-noinstall.zip`（绿色免安装，解压即用）
  - `nvm-setup.exe`（官方安装器，自动配置）
  - 各自带 `checksum.txt`
- 需要管理员权限（`nvm use` 创建符号链接）
- 符号链接机制：`NVM_HOME` 存 nvm 本体 + 各 node 版本，`NVM_SYMLINK` 是当前激活版本的
  符号链接（加入 PATH），切换版本只改符号链接目标

## 镜像 / 源配置（重点）

- node 下载镜像：`nvm node_mirror https://npmmirror.com/mirrors/node/`
- npm 下载镜像：`nvm npm_mirror https://npmmirror.com/mirrors/npm/`
- npm registry：`npm config set registry https://registry.npmmirror.com`

## 绿色部署方案（对应 ohmyenv 部署包）

1. `nvm-noinstall.zip` 解压到 `D:\ohmyenv\nvm`（nvm.exe）
2. 设置用户环境变量：`NVM_HOME = D:\ohmyenv\nvm`、`NVM_SYMLINK = D:\ohmyenv\nodejs`
3. PATH 前置 `D:\ohmyenv\nodejs`（符号链接，实际指向当前 node 版本）+ `D:\ohmyenv\nvm`
4. 配置镜像：`nvm node_mirror` / `nvm npm_mirror` → npmmirror
5. `nvm install <版本|latest|lts>` + `nvm use <版本>`（需管理员，创建符号链接）
6. `npm config set registry https://registry.npmmirror.com`

## omc 旧 node 现状

- omc `node.ps1`：USTC 镜像（`mirrors.ustc.edu.cn`）下载，默认 24.14.1，SHA256 校验
- 位置：`D:\Oh-My-Claude\.envs\dev\node`
- 当前 node/npm 不在用户 PATH（omc 未注册 PATH 或已清理）

## 接管决策

- nvm-windows 的「多版本 + 符号链接」与 ohmyenv 的「单版本 pin + 绿色目录」不同，建议：
  - nvm 本体走 ohmyenv 部署包（nvm-noinstall.zip 解压 + 环境变量）
  - node 版本由 nvm 管理（`nvm install` / `nvm use`），ohmyenv 只 pin nvm 本体版本
  - 镜像/registry 配置沉淀为 `scripts\set-node-config.ps1`（幂等）
- 接管前需清理 omc 旧 node（`$DevTools` 移除 node + 文件改名/删除）

