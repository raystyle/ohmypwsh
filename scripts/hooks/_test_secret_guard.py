import json
import os
import subprocess
import sys


GUARD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "secret-guard.py")
PY = sys.executable


def run(payload, env=None):
    e = dict(os.environ)
    if env:
        e.update(env)
    p = subprocess.run(
        [PY, GUARD],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        encoding="utf-8",
        env=e,
    )
    return p.returncode, p.stdout.strip(), p.stderr.strip()


CASES = [
    ("claude PreToolUse secret", {
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": "curl -H 'Authorization: Bearer ghp_abcdefghijklmnopqrstuvwxyz0123456789' https://x"},
    }, None, 2),
    ("kimi UserPromptSubmit secret", {
        "hook_event_name": "UserPromptSubmit",
        "prompt": "use this key sk-ant-abcdefghijklmnopqrstuvwxyz0123456789",
    }, None, 2),
    ("codex PreToolUse secret", {
        "tool_name": "Bash",
        "tool_input": {"command": "export DEEPSEEK_API_KEY=sk-abcdefghijklmnopqrstuvwxyz0123456789"},
    }, None, 2),
    ("codex PostToolUse secret", {
        "tool_name": "Bash",
        "tool_response": "ok: password = 'supersecret123'",
    }, None, 0),
    ("reasonix PreToolUse secret", {
        "event": "PreToolUse",
        "cwd": "D:/repo",
        "toolName": "bash",
        "toolArgs": {"command": "git push origin main && echo AKIAIOSFODNN7EXAMPLE"},
    }, None, 2),
    ("reasonix UserPromptSubmit secret", {
        "event": "UserPromptSubmit",
        "cwd": "D:/repo",
        "prompt": "mongodb+srv://admin:hunter2@cluster.example.com/db",
        "turn": 1,
    }, None, 2),
    ("reasonix PostToolUse secret", {
        "event": "PostToolUse",
        "cwd": "D:/repo",
        "toolName": "bash",
        "toolArgs": {"command": "cat .env"},
        "toolResult": "postgresql://user:pa55word@localhost/db",
    }, None, 2),
    ("reasonix clean", {
        "event": "PreToolUse",
        "cwd": "D:/repo",
        "toolName": "bash",
        "toolArgs": {"command": "git status --short"},
    }, None, 0),
    ("codex clean prompt", {
        "prompt": "rename the function to parse_config",
    }, None, 0),
]


def main():
    failures = 0
    for name, payload, env, expect in CASES:
        code, out, err = run(payload, env)
        ok = code == expect
        if not ok:
            failures += 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}: exit={code} expect={expect}")
        if not ok:
            print(f"  stdout: {out[:200]!r}")
            print(f"  stderr: {err[:300]!r}")
    print(f"\n{len(CASES) - failures}/{len(CASES)} passed")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
