# 密钥管理：age + SOPS（Windows / pwsh）

> 2026-08-19 落地。与通用指南的区别：工具不装 `%USERPROFILE%\bin`，
> 而是接入本项目 `scripts\ohmyenv.ps1`，统一走 api.github.com 查询下载、
> 版本锁定与 sha256 校验（bootstrap 不依赖 gh，符合设计原则）。

## 工具版本（已锁定，`scripts\env.psd1`）

| 工具 | 版本 | 安装位置 | 用途 |
| --- | --- | --- | --- |
| age | 1.3.1 | `D:\ohmyenv\age` | 非对称加密 |
| sops | 3.13.3 | `D:\ohmyenv\sops` | 文件级加密编排（age 为后端） |

更新：`ohmyenv update age` / `ohmyenv update sops`。

## 密钥位置与环境变量

```powershell
# 私钥（绝不提交）
%APPDATA%\sops\age\keys.txt

# 公钥（可提交，已写入项目 .sops.yaml）
age1wsgcklmca5mayu4n6jhry5jphvk3tzlt8xqjtajs06y5yagwh4zqshk05k

# 用户环境变量（已设置）
SOPS_AGE_KEY_FILE=%APPDATA%\sops\age\keys.txt
```

## 使用

```powershell
# 加密（dotenv → dotenv），flags 必须在文件路径之前
sops --config .sops.yaml --encrypt --input-type dotenv --output-type dotenv --output .env.enc .env

# 解密
sops --config .sops.yaml --decrypt --input-type dotenv --output-type dotenv .env.enc
```

冒烟测试（随机值，加密 → 明文泄漏检查 → 解密比对）：

```powershell
pwsh -NoProfile -File scripts\sops-test.ps1
```

## 踩过的坑（规则 1 沉淀）

- **sops 参数顺序**：`--output` 等 flags 必须放在位置参数（文件路径）之前，否则被当作多余位置参数忽略、结果只打到 stdout
- **age zip 有顶层 `age/` 包裹层**：`Expand-Archive` 会解出 `age\age\age.exe`；ohmyenv 的 `zip` 解压已加“单目录展平”
- **含密钥样字面量的命令会被安全策略拦截**：测试脚本改为运行时随机生成值（`scripts\sops-test.ps1`）
- `age-keygen` 提示 world-readable 属正常（Windows 下权限模型不同）
- 私钥 `keys.txt` 与 `*.agekey` 已在 `.gitignore` 保护；`.sops.yaml` 只含公钥，可安全提交
- 对数组用 `-notmatch` 判断会误报（数组语义）→ 用整行相等匹配
