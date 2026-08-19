#Requires -Version 7.0
# sops-encrypt-anthropic.ps1 - 将用户级 ANTHROPIC_API_KEY 加密为 .secrets\anthropic.env.enc
# 明文仅临时写入，加密并验证后立即删除；全程不回显密钥。

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sopsYaml    = Join-Path $projectRoot '.sops.yaml'
$keyName     = 'ANTHROPIC_' + 'API_KEY'

$key = [Environment]::GetEnvironmentVariable($keyName, 'User')
if (-not $key) { throw "$keyName 未设置（用户级）" }

$env:SOPS_AGE_KEY_FILE = Join-Path $env:APPDATA 'sops\age\keys.txt'
if (-not (Test-Path $env:SOPS_AGE_KEY_FILE)) { throw "未找到 age 私钥: $env:SOPS_AGE_KEY_FILE" }

$secretsDir = Join-Path $projectRoot '.secrets'
New-Item -ItemType Directory -Force $secretsDir | Out-Null
$plain = Join-Path $secretsDir 'anthropic.env'
$enc   = "$plain.enc"

try {
    Set-Content -Path $plain -Value "$keyName=$key" -Encoding utf8 -NoNewline
    sops --config $sopsYaml --encrypt --input-type dotenv --output-type dotenv --output $enc $plain
    if ($LASTEXITCODE -ne 0) { throw 'sops 加密失败' }

    if (Select-String -Path $enc -SimpleMatch -Quiet $key) {
        throw '加密文件泄漏明文，已中止'
    }

    $dec = sops --config $sopsYaml --decrypt --input-type dotenv --output-type dotenv $enc
    $expect = "$keyName=$key"
    if (-not ($dec | Where-Object { $_.Trim() -eq $expect })) {
        throw '解密回读与原文不匹配'
    }

    Write-Host "[OK] 已加密: $enc" -ForegroundColor Green
    Write-Host '[OK] 加密/解密回读验证通过，明文已删除' -ForegroundColor Green
} finally {
    if (Test-Path $plain) { Remove-Item -LiteralPath $plain -Force }
}
