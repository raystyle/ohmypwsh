#!/usr/bin/env python3
"""
Agent Secret Guard Hook (Claude Code + Codex CLI)

Detects and blocks API keys / credentials in prompts and tool I/O.
Target auto-detection:
  - Claude Code: input JSON contains `hook_event_name`.
  - Codex CLI:   input JSON contains `tool_name` / `prompt` / `tool_response`.

Block semantics:
  - Claude Code: stderr + exit 2 for any finding.
  - Codex PreToolUse/UserPromptSubmit: JSON permissionDecision=deny + exit 2.
  - Codex PostToolUse: JSON output replacement + exit 0.
"""

import json
import os
import re
import sys


SECRET_PATTERNS = [
    (r"sk-[a-zA-Z0-9_-]{20,}", "OpenAI API Key"),
    (r"AKIA[0-9A-Z]{16}", "AWS Access Key ID"),
    (r"ASIA[0-9A-Z]{16}", "AWS Session Key"),
    (r"ghp_[a-zA-Z0-9]{36}", "GitHub Personal Token"),
    (r"gho_[a-zA-Z0-9]{36}", "GitHub OAuth Token"),
    (r"sk-ant-[a-zA-Z0-9_-]{20,}", "Anthropic API Key"),
    (r"AIza[0-9A-Za-z_-]{35}", "Google API Key"),
    (r"xox[baprs]-[0-9a-zA-Z]{10,48}", "Slack Token"),
    (r"api[_-]?key\s*[:=]\s*[\"']?[a-zA-Z0-9]{16,}[\"']?", "Generic API Key"),
    (r"secret[_-]?key\s*[:=]\s*[\"']?[a-zA-Z0-9]{16,}[\"']?", "Generic Secret Key"),
    (r"password\s*[:=]\s*[\"'][^\"']{8,}[\"']", "Hardcoded Password"),
    (r"-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----", "PEM Private Key"),
    (r"eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*", "JWT Token"),
    (r"mongodb\+srv://[^:]+:[^@]+@", "MongoDB URI with password"),
    (r"postgres(ql)?://[^:]+:[^@]+@", "PostgreSQL URI with password"),
]

SECRET_ENV_NAMES = [
    "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY", "GITHUB_TOKEN", "DATABASE_URL",
    "SECRET_KEY", "API_KEY", "JWT_SECRET", "PRIVATE_KEY",
    "DEEPSEEK_API_KEY",
]


def scan_text(text, context=""):
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
        if env_value and env_value in text:
            findings.append({
                "type": f"Env Leak: {env_name}",
                "matched": env_name,
                "context": "Real secret value from environment detected",
            })
    return findings


def build_message(findings, context):
    lines = [
        " SECURITY ALERT: Potential secret leakage detected!",
        f"Context: {context}",
        f"Found {len(findings)} suspicious pattern(s):",
    ]
    for i, f in enumerate(findings, 1):
        lines.append(f"  {i}. [{f['type']}] {f.get('matched', 'N/A')}")
    lines.append("\n⚠️  Action blocked to prevent credential exposure.")
    lines.append("Please remove any API keys/tokens from your request.")
    return "\n".join(lines)


def main():
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        data = {}

    is_claude = "hook_event_name" in data
    if is_claude:
        event = data.get("hook_event_name", "unknown")
        if event == "PreToolUse":
            tool_name = data.get("tool_name", "")
            tool_input = data.get("tool_input", {})
            text = tool_input.get("command", "") if tool_name == "Bash" else json.dumps(tool_input)
            context = "Bash command" if tool_name == "Bash" else f"{tool_name} tool"
        elif event == "PostToolUse":
            text = str(data.get("tool_response", ""))
            context = f"{data.get('tool_name', '')} output"
        elif event == "UserPromptSubmit":
            text = data.get("prompt", "")
            context = "user prompt"
        else:
            text = json.dumps(data)
            context = event
    else:
        event = "PreToolUse"
        text = ""
        context = "unknown"
        if "tool_name" in data:
            tool_name = data.get("tool_name", "")
            if "tool_response" in data or "output" in data:
                event = "PostToolUse"
                text = str(data.get("tool_response", data.get("output", "")))
                context = f"{tool_name} output"
            else:
                event = "PreToolUse"
                tool_input = data.get("tool_input", {})
                text = tool_input.get("command", "") if tool_name == "Bash" else json.dumps(tool_input)
                context = "Bash command" if tool_name == "Bash" else f"{tool_name} tool"
        elif "prompt" in data:
            event = "UserPromptSubmit"
            text = data.get("prompt", "")
            context = "user prompt"
        else:
            text = json.dumps(data)

    findings = scan_text(text, context)
    findings.extend(check_env_leak(text))

    if not findings:
        sys.exit(0)

    error_msg = build_message(findings, context)

    if is_claude:
        sys.stderr.write(error_msg + "\n")
        sys.exit(2)

    if event in ("PreToolUse", "UserPromptSubmit"):
        sys.stderr.write(error_msg + "\n")
        print(json.dumps({
            "permissionDecision": "deny",
            "permissionDecisionReason": error_msg,
            "hookSpecificOutput": {
                "permissionDecision": "deny",
                "reason": error_msg,
            },
        }))
        sys.exit(2)

    # Codex PostToolUse: replace output with warning, exit 0.
    print(json.dumps({"output": error_msg, "secret_scan_blocked": True}))
    sys.exit(0)


if __name__ == "__main__":
    main()
