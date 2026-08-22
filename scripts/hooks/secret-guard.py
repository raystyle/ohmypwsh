#!/usr/bin/env python3
"""
Unified Agent Secret Guard Hook.

Compatible with four CLIs, auto-detected from their stdin JSON envelope:
  - Claude Code        : hook_event_name + snake_case (tool_name / tool_input / tool_response)
  - Kimi Code CLI      : hook_event_name + snake_case (Claude-shaped)
  - Codex CLI          : snake_case, no hook_event_name (event inferred from payload)
  - Reasonix           : event + camelCase (toolName / toolArgs / toolResult)

Blocking semantics:
  - PreToolUse / UserPromptSubmit block the operation (exit 2).
  - PostToolUse is observation-only in every CLI: findings become a warning;
    Codex additionally gets output replacement.
  - Any unexpected error fails open (exit 0) so a broken guard never stalls the agent.
"""

import json
import os
import re
import sys
import tempfile
import time


SECRET_PATTERNS = [
    (r"sk-proj-[A-Za-z0-9_-]{20,}", "OpenAI Project Key"),
    (r"sk-svcacct-[A-Za-z0-9_-]{20,}", "OpenAI Service Account Key"),
    (r"sk-ant-[a-zA-Z0-9_-]{20,}", "Anthropic API Key"),
    (r"sk_live_[a-zA-Z0-9]{24,}", "Stripe Live Secret Key"),
    (r"sk_test_[a-zA-Z0-9]{24,}", "Stripe Test Secret Key"),
    (r"sk-[a-zA-Z0-9_-]{20,}", "OpenAI API Key"),
    (r"kimi-[a-zA-Z0-9]{24,}", "Kimi API Key"),
    (r"moonshot-[a-zA-Z0-9]{24,}", "Moonshot API Key"),
    (r"AKIA[0-9A-Z]{16}", "AWS Access Key ID"),
    (r"ASIA[0-9A-Z]{16}", "AWS Session Key"),
    (r"ghp_[a-zA-Z0-9]{36}", "GitHub Personal Token"),
    (r"gho_[a-zA-Z0-9]{36}", "GitHub OAuth Token"),
    (r"ghu_[a-zA-Z0-9]{36}", "GitHub User Token"),
    (r"glpat-[a-zA-Z0-9_-]{20,}", "GitLab Personal Token"),
    (r"xox[baprs]-[0-9a-zA-Z]{10,48}", "Slack Token"),
    (r"AIza[0-9A-Za-z_-]{35}", "Google API Key"),
    (r"eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*", "JWT Token"),
    (r"-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----", "PEM Private Key"),
    (r"mongodb\+srv://[^:]+:[^@\s]+@", "MongoDB URI with password"),
    (r"postgres(ql)?://[^:]+:[^@\s]+@", "PostgreSQL URI with password"),
    (r"mysql://[^:]+:[^@\s]+@", "MySQL URI with password"),
    (r"redis://[^:]+:[^@\s]+@", "Redis URI with password"),
    (r"api[_-]?key\s*[:=]\s*[\"']?[A-Za-z0-9_.\-]{16,}[\"']?", "Generic API Key"),
    (r"secret[_-]?key\s*[:=]\s*[\"']?[A-Za-z0-9_.\-]{16,}[\"']?", "Generic Secret Key"),
    (r"token\s*[:=]\s*[\"']?[A-Za-z0-9_.\-]{16,}[\"']?", "Generic Token"),
    (r"bearer\s+[A-Za-z0-9_\-\.]{20,}", "Bearer Token"),
    (r"password\s*[:=]\s*\"[^\"']{8,}\"", "Hardcoded Password (double-quoted)"),
    (r"password\s*[:=]\s*'[^\"']{8,}'", "Hardcoded Password (single-quoted)"),
    (r"password\s*[:=]\s*[^\"'\s]{8,}[\"']?", "Hardcoded Password (bare)"),
]

SECRET_ENV_NAMES = [
    "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
    "AWS_SESSION_TOKEN", "GITHUB_TOKEN", "GITLAB_TOKEN", "SLACK_TOKEN", "STRIPE_SECRET_KEY",
    "DATABASE_URL", "REDIS_URL", "MONGO_URI", "MONGODB_URI", "PRIVATE_KEY", "SECRET_KEY",
    "API_KEY", "AUTH_TOKEN", "BEARER_TOKEN", "JWT_SECRET", "KIMI_API_KEY", "MOONSHOT_API_KEY",
    "AZURE_OPENAI_API_KEY", "GOOGLE_API_KEY", "DEEPSEEK_API_KEY", "REASONIX_API_KEY",
]


def guard_self_file(file_path):
    """判定某路径是否属于 guard 自身 / 其研究文档（其内容是密钥模式声明，不是真密钥）。
    - guard 脚本本体（secret-guard.py）允许出现在仓库与各 agent hooks 目录，按 basename 豁免；
    - 研究/审查文档限定在仓库 docs/research 内（其内容是合法模式字面量）。"""
    if not file_path:
        return False
    p = str(file_path).replace("\\", "/").strip().lower()
    if not p.startswith("/"):
        p = "/" + p   # 归一化，使相对路径（如 scripts/hooks/secret-guard.py）也能匹配
    # guard 脚本本体（部署于 scripts/hooks 及各 agent 的 hooks 目录）
    if p.endswith("/secret-guard.py"):
        return True
    # 研究/审查文档：限定 docs/research 内的固定文档（路径已统一为 /）
    if "/docs/research/" in p:
        base = p.rsplit("/", 1)[-1]
        if base in ("agent-secret-guard.md", "win-rmux-multi-agent-review.md", "win-rmux-pitfalls-accumulate.md"):
            return True
    return False


def detect_cli_format(payload):
    """Return 'reasonix' | 'claude' (Claude + Kimi share the envelope) | 'codex'."""
    if "event" in payload:
        return "reasonix"
    if "hook_event_name" in payload:
        return "claude"
    return "codex"


def get_event_type(payload, cli_format):
    if cli_format == "reasonix":
        return payload.get("event", "unknown")

    if cli_format == "claude":
        env_event = os.environ.get("CLAUDE_HOOK_EVENT")
        if env_event:
            return env_event
        return payload.get("hook_event_name", "unknown")

    # Codex: prefer an explicit env marker, otherwise infer from the payload shape.
    env_event = os.environ.get("CODEX_HOOK_EVENT")
    if env_event:
        return env_event
    if any(k in payload for k in ("tool_response", "tool_output", "output")):
        return "PostToolUse"
    if "tool_name" in payload:
        return "PreToolUse"
    if "prompt" in payload:
        return "UserPromptSubmit"
    return "unknown"


def get_text_to_scan(payload, event_type, cli_format):
    text, context = "", event_type

    if event_type == "PreToolUse":
        if cli_format == "reasonix":
            tool_name = payload.get("toolName", "")
            tool_args = payload.get("toolArgs", {})
            if isinstance(tool_args, dict) and tool_name.lower() in ("bash", "shell", "powershell", "pwsh"):
                text = tool_args.get("command", "")
                context = "Bash command"
            else:
                text = json.dumps(tool_args) if tool_args else ""
                context = f"{tool_name} tool"
        else:
            tool_name = payload.get("tool_name", "")
            tool_input = payload.get("tool_input", {})
            if isinstance(tool_input, dict):
                if tool_name == "Bash":
                    text = tool_input.get("command", "")
                    context = "Bash command"
                elif tool_name in ("Read", "Write", "Edit", "ReadFile", "WriteFile", "StrReplaceFile"):
                    file_path = tool_input.get("file_path", tool_input.get("path", ""))
                    content = tool_input.get("content", "")
                    # 豁免 guard 自身/其研究文档：这些文件是「密钥模式的声明/文档」，本身不是真密钥，
                    # 扫描它们会因内容含 mysql://、api_key 等模式字面量而误拦（review 实测踩到）。
                    if guard_self_file(file_path):
                        text = ""  # 跳过扫描
                        context = f"{tool_name} file (guard self-exempt)"
                    else:
                        text = f"{file_path} {content}"
                        context = f"{tool_name} file"
                else:
                    text = json.dumps(tool_input)
                    context = f"{tool_name} tool"
            else:
                text = json.dumps(tool_input) if tool_input else ""
                context = f"{tool_name} tool"

    elif event_type == "PostToolUse":
        if cli_format == "reasonix":
            tool_name = payload.get("toolName", "")
            tool_result = payload.get("toolResult", payload.get("output", ""))
            # Reasonix Read/Write 输出（guard 自身/文档）可豁免
            tinput = payload.get("toolArgs", {})
            fp = tinput.get("file_path", tinput.get("path", "")) if isinstance(tinput, dict) else ""
            if guard_self_file(fp):
                text, context = "", f"{tool_name} output (guard self-exempt)"
            else:
                text = str(tool_result)
                context = f"{tool_name} output"
        else:
            tool_name = payload.get("tool_name", "")
            tinput = payload.get("tool_input", {})
            fp = tinput.get("file_path", tinput.get("path", "")) if isinstance(tinput, dict) else ""
            tool_response = payload.get("tool_response", payload.get("output", payload.get("tool_output", "")))
            if guard_self_file(fp):
                # Read/Edit guard 自身文件的输出（内容即模式定义）不再误拦
                text, context = "", f"{tool_name} output (guard self-exempt)"
            else:
                text = str(tool_response)
                context = f"{tool_name} output"

    elif event_type == "UserPromptSubmit":
        text = payload.get("prompt", "")
        context = "user prompt"

    else:
        text = json.dumps(payload)
        context = event_type

    return text, context


def scan_text(text, context):
    findings = []
    for pattern, label in SECRET_PATTERNS:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            found = match.group(0)
            masked = (found[:4] + "*" * max(0, len(found) - 8) + found[-4:]) if len(found) > 8 else "*" * len(found)
            findings.append({"type": label, "matched": masked, "context": context})
    return findings


def check_env_leak(text):
    findings = []
    for env_name in SECRET_ENV_NAMES:
        env_value = os.environ.get(env_name)
        if env_value and len(env_value) >= 8 and env_value in text:
            findings.append({
                "type": f"Environment Variable Leak: {env_name}",
                "matched": env_name,
                "context": "Real secret value from environment detected",
            })
    return findings


def build_block_message(findings, context):
    lines = [
        "SECURITY ALERT: Potential secret leakage detected!",
        f"Context: {context}",
        f"Found {len(findings)} suspicious pattern(s):",
    ]
    for i, f in enumerate(findings, 1):
        lines.append(f"  {i}. [{f['type']}] {f.get('matched', 'N/A')}")
    lines.append("Action blocked to prevent credential exposure.")
    lines.append("Remove any API keys, tokens, or passwords from the request.")
    return "\n".join(lines)


def _log_path():
    """日志路径：SECRET_GUARD_LOG 覆盖 > 平台默认；'off' 关闭日志。
    只记元数据/判定/命中类型，绝不记录被扫描文本或密钥明文（排查误报用）。"""
    v = os.environ.get("SECRET_GUARD_LOG", "").strip()
    if v.lower() in ("off", "0", "false", "none"):
        return None
    if v:
        return v
    if os.name == "nt":
        base = os.environ.get("LOCALAPPDATA") or tempfile.gettempdir()
        return os.path.join(base, "ohmyenv", "secret-guard.log")
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
    return os.path.join(base, "ohmyenv", "secret-guard.log")


def log_run(verdict, cli_format, event_type, text_len, hit_types=(), error=None, extra=None):
    """写一条单行 JSON 日志（append）。任何异常都静默忽略，日志绝不反噬 hook 判定。"""
    path = _log_path()
    if not path:
        return
    try:
        d = os.path.dirname(path)
        if d:
            os.makedirs(d, exist_ok=True)
        rec = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "verdict": verdict,          # pass | block | warn | error
            "cli": cli_format,
            "event": event_type,
            "text_len": text_len,
            "hits": list(hit_types),     # 只记命中类型（如 'OpenAI API Key'），不记匹配文本
        }
        if error is not None:
            rec["error"] = str(error)
        if extra:
            rec.update(extra)
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except Exception:
        pass


def _read_raw_stdin():
    """读 hook stdin 的 raw bytes；读不到返回 None。"""
    try:
        return sys.stdin.buffer.read()
    except Exception:
        try:
            return sys.stdin.read().encode("utf-8", errors="replace")
        except Exception:
            return None


def _decode_candidates(data):
    """按优先级返回 (encoding, text) 候选：编码自愈。
    优先 BOM 精确判定，其次常见编码；调用方逐个尝试 json 解析，成功即用。"""
    if not data:
        return
    # BOM 精确优先（命中 BOM 就不要再去试其它）
    if data[:3] == b"\xef\xbb\xbf":
        yield ("utf-8-sig", data[3:].decode("utf-8-sig", errors="strict"))
        return
    if data[:2] == b"\xff\xfe":     # UTF-16 LE BOM
        yield ("utf-16-le", data[2:].decode("utf-16-le", errors="strict"))
        return
    if data[:2] == b"\xfe\xff":     # UTF-16 BE BOM
        yield ("utf-16-be", data[2:].decode("utf-16-be", errors="strict"))
        return
    # 无 BOM：一级备选就这几个编码（严格解码失败则跳过，不引入 latin-1 这种全量通过候选）
    for enc in ("utf-8", "utf-16-le", "utf-16-be", "gbk"):
        try:
            yield (enc, data.decode(enc, errors="strict"))
        except UnicodeDecodeError:
            continue


def main():
    try:
        raw = _read_raw_stdin()
        if not raw or not raw.strip():
            log_run("pass", "unknown", "empty", 0)
            sys.exit(0)

        # 编码自愈：候选编码逐个 decode + json.loads，成功即用；全部失败才 fail-open
        payload = None
        used_enc = None
        stdin_text = ""
        parse_errors = []
        for enc, text in _decode_candidates(raw):
            if not text.strip():
                continue
            try:
                obj = json.loads(text)
                payload = obj
                used_enc = enc
                stdin_text = text
                break
            except Exception as exc:
                parse_errors.append(f"{enc}: {exc}")
        if payload is None:
            raise ValueError("stdin JSON 解析失败（各编码均失败）: " + "; ".join(parse_errors[-3:]))
        if not isinstance(payload, dict):
            log_run("pass", "unknown", "non-dict", len(stdin_text))
            sys.exit(0)

        cli_format = detect_cli_format(payload)
        event_type = get_event_type(payload, cli_format)
        text_to_scan, context = get_text_to_scan(payload, event_type, cli_format)

        findings = scan_text(text_to_scan, context)
        findings.extend(check_env_leak(text_to_scan))

        if not findings:
            log_run("pass", cli_format, event_type, len(text_to_scan))
            sys.exit(0)

        message = build_block_message(findings, context)
        print(message, file=sys.stderr)
        hit_types = [f["type"] for f in findings]

        # Codex PostToolUse is observation-only; replace its output with the warning.
        if cli_format == "codex" and event_type == "PostToolUse":
            log_run("warn", cli_format, event_type, len(text_to_scan), hit_types)
            print(json.dumps({"output": message, "secret_scan_blocked": True}))
            sys.exit(0)

        # Codex PreToolUse / UserPromptSubmit also expect an explicit deny decision.
        if cli_format == "codex" and event_type in ("PreToolUse", "UserPromptSubmit"):
            log_run("block", cli_format, event_type, len(text_to_scan), hit_types)
            print(json.dumps({
                "permissionDecision": "deny",
                "permissionDecisionReason": message,
                "hookSpecificOutput": {
                    "permissionDecision": "deny",
                    "reason": message,
                },
            }))

        # exit 2 blocks for PreToolUse/UserPromptSubmit in every CLI and is a
        # warning for observation-only events (Reasonix/Kimi/Claude PostToolUse).
        verdict = "block" if event_type in ("PreToolUse", "UserPromptSubmit") else "warn"
        log_run(verdict, cli_format, event_type, len(text_to_scan), hit_types)
        sys.exit(2)

    except Exception as exc:  # noqa: BLE001 - fail-open by design
        log_run("error", "unknown", "unknown", 0, error=exc)
        print(f"Secret Guard encountered an error: {exc}", file=sys.stderr)
        print("Allowing operation to proceed (fail-open policy).", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
