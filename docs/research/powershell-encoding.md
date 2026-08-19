# PS5 与 PS7 编码兼容研究（优先注意规则）

## 主题

Windows PowerShell 5.1 与 PowerShell 7 对文本文件编码的读取差异，以及由此引发的模块/脚本兼容问题。实测触发场景：自研模块 manifest（UTF-8 无 BOM + 中文描述）在 5.1 解析失败。

## 核心差异（实测）

| 项目 | PS5.1（.NET Framework） | PS7（.NET 10） |
| --- | --- | --- |
| 无 BOM 文件默认编码 | **ANSI（本地代码页，中文系统为 GBK）** | UTF-8 |
| UTF-8 无 BOM + 非 ASCII | 按 GBK 误读 → mojibake / 解析报错 | 正常 |
| UTF-8 带 BOM | 正常 | 正常 |
| `Set-Content -Encoding utf8`（pwsh7） | 无 BOM → 5.1 有风险 | 正常 |
| `Set-Content -Encoding utf8BOM`（pwsh7） | 正常 | 正常 |

实测报错形态（5.1 读 UTF-8 无 BOM 的 psd1）：

```text
The module manifest '...psd1' could not be processed because it is not a valid
Windows PowerShell restricted language file. ... The string is missing the terminator: "
```

## 优先注意规则（AGENTS 规则 4）

1. **凡需兼容 PS5.1 的 `.psd1` / `.ps1` 文件，含非 ASCII 内容时必须 UTF-8 带 BOM**（或纯 ASCII）；`pwsh7` 的 `Set-Content -Encoding utf8` 是无 BOM，需改用 `utf8BOM` 或 `[System.Text.UTF8Encoding]::new($true)` 写入
2. 纯 ASCII 内容两种编码均可，但写文件统一用带 BOM 可免后续踩坑
3. 读取文件时优先显式指定编码（`Get-Content -Encoding UTF8`），不依赖探测；PS5.1 读无 BOM 文件按本地代码页，跨机器（如中文/英文系统）行为不一致
4. PSGallery 发布的 nupkg 内 manifest 通常已带 BOM，可直接部署；**自研模块的 manifest 由作者负责保证编码**（`psmodule.ps1 pack` 原样打包，不做编码改写）
5. 输出/控制台编码另注意：PS5.1 控制台默认 OEM/系统代码页，PS7 默认 UTF-8；脚本间传文件时注意两侧读写编码一致性

## 结论

- 模块管理器（`psmodule.ps1`）在线安装 PSGallery 包无编码风险；离线/自研包的风险点在作者侧 manifest 编码
- 编码兼容是 PS5/PS7 双支持的「优先注意」项，先于功能调试排查
