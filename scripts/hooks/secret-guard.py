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
    (r"password\s*[:=]\s*[\"']?[^\"'\s]{8,}[\"']?", "Hardcoded Password"),
]

SECRET_ENV_NAMES = [
    "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY",
    "AWS_SESSION_TOKEN", "GITHUB_TOKEN", "GITLAB_TOKEN", "SLACK_TOKEN", "STRIPE_SECRET_KEY",
    "DATABASE_URL", "REDIS_URL", "MONGO_URI", "MONGODB_URI", "PRIVATE_KEY", "SECRET_KEY",
    "API_KEY", "AUTH_TOKEN", "BEARER_TOKEN", "JWT_SECRET", "KIMI_API_KEY", "MOONSHOT_API_KEY",
    "AZURE_OPENAI_API_KEY", "GOOGLE_API_KEY", "DEEPSEEK_API_KEY", "REASONIX_API_KEY",
]


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
                    base = os.path.basename(str(file_path)).lower()
                    if base in ("secret-guard.py", "agent-secret-guard.md", "win-rmux-multi-agent-review.md"):
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
            text = str(tool_result)
            context = f"{tool_name} output"
        else:
            tool_name = payload.get("tool_name", "")
            tool_response = payload.get("tool_response", payload.get("output", payload.get("tool_output", "")))
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


def main():
    try:
        stdin_text = sys.stdin.read()
        if not stdin_text.strip():
            sys.exit(0)

        payload = json.loads(stdin_text)
        if not isinstance(payload, dict):
            sys.exit(0)

        cli_format = detect_cli_format(payload)
        event_type = get_event_type(payload, cli_format)
        text_to_scan, context = get_text_to_scan(payload, event_type, cli_format)

        findings = scan_text(text_to_scan, context)
        findings.extend(check_env_leak(text_to_scan))

        if not findings:
            sys.exit(0)

        message = build_block_message(findings, context)
        print(message, file=sys.stderr)

        # Codex PostToolUse is observation-only; replace its output with the warning.
        if cli_format == "codex" and event_type == "PostToolUse":
            print(json.dumps({"output": message, "secret_scan_blocked": True}))
            sys.exit(0)

        # Codex PreToolUse / UserPromptSubmit also expect an explicit deny decision.
        if cli_format == "codex" and event_type in ("PreToolUse", "UserPromptSubmit"):
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
        sys.exit(2)

    except Exception as exc:  # noqa: BLE001 - fail-open by design
        print(f"Secret Guard encountered an error: {exc}", file=sys.stderr)
        print("Allowing operation to proceed (fail-open policy).", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
