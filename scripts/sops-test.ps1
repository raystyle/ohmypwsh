#Requires -Version 7.0
# sops-test.ps1 - SOPS + age 冒烟测试（加密/解密往返验证，测试值运行时随机生成）

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sopsYaml    = Join-Path $projectRoot '.sops.yaml'

if (-not $env:SOPS_AGE_KEY_FILE) {
    $env:SOPS_AGE_KEY_FILE = Join-Path $env:APPDATA 'sops\age\keys.txt'
}
if (-not (Test-Path $env:SOPS_AGE_KEY_FILE)) {
    throw "未找到 age 私钥: $env:SOPS_AGE_KEY_FILE（先运行 age-keygen 生成）"
}

$tmp = Join-Path $env:TEMP ('sops-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
    $testEnv = Join-Path $tmp 'test.env'
    $values = [ordered]@{
        'API_KEY'     = 'sk-' + [guid]::NewGuid().ToString('N')
        'DB_PASSWORD' = 'secret-' + [guid]::NewGuid().ToString('N')
    }
    $lines = foreach ($k in $values.Keys) { "$k=$($values[$k])" }
    $lines | Set-Content $testEnv -Encoding utf8

    Write-Host '=== encrypt ===' -ForegroundColor Cyan
    sops --config $sopsYaml --encrypt --input-type dotenv --output-type dotenv --output "$testEnv.enc" $testEnv

    Write-Host '=== check no plaintext leak ===' -ForegroundColor Cyan
    foreach ($v in $values.Values) {
        if (Select-String -Path "$testEnv.enc" -SimpleMatch -Quiet $v) {
            throw "加密文件泄漏明文值: $v"
        }
    }
    '[OK] 加密文件中未发现明文'

    Write-Host '=== decrypt ===' -ForegroundColor Cyan
    $decrypted = sops --config $sopsYaml --decrypt --input-type dotenv --output-type dotenv "$testEnv.enc"
    foreach ($k in $values.Keys) {
        $expect = "$k=$($values[$k])"
        if (-not ($decrypted | Where-Object { $_.Trim() -eq $expect })) {
            throw "解密值不匹配: $k"
        }
    }
    Write-Host '[OK] SOPS + age 冒烟测试通过' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force
}
