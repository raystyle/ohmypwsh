#!/bin/bash
# ===================================================
# tool-versions.sh — 输出镜像内工具版本（每行 `name: version`）
# 单一来源：build.ps1（构建报告）与 verify.ps1 --full（报告比对）共用，
# 避免两处探测逻辑漂移（如 gopls 用 --version 的坑）。
# 用法: bash tool-versions.sh
# ===================================================
export PATH="$HOME/.local/bin:$HOME/.local/zig/current:$HOME/.bun/bin:$HOME/.cargo/bin:$HOME/go/bin:/usr/local/go/bin:$PATH"

for c in git jq node bun rustc cargo uv go zig rust-analyzer gopls zls gcc g++ cmake ninja pkg-config openssl; do
  if command -v "$c" >/dev/null 2>&1; then
    case "$c" in
      go)      echo "$c: $(go version 2>&1 | head -1 || true)" ;;
      gopls)   echo "$c: $(gopls version 2>&1 | head -1 || true)" ;;
      openssl) echo "$c: $(openssl version 2>&1 | head -1 || true)" ;;
      zig)     echo "$c: $(zig version 2>&1 | head -1 || true)" ;;
      *)       echo "$c: $($c --version 2>&1 | head -1 || true)" ;;
    esac
  else
    echo "$c: MISSING"
  fi
done
