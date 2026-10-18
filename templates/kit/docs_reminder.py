"""Stop hook: keep the docs step from being skipped.

Run by `.agents/kit/stop-hook.sh` when an agent ends a turn. It reads the
session transcript (Claude Code's format; other agents may differ, and then
it does nothing) and:

1. after a turn that edited files or ran shell commands (a `sed` edit leaves
   no edit call), runs `.agents/kit/check.sh` and blocks the stop with the
   failures;
2. when the turn edited code but no Markdown file, blocks once and asks for
   the docs step, or a one-line "no doc needed".

`stop_hook_active` is set on the follow-up stop, so it never loops. Any
error lets the stop through. Installed by agent_dev_kit; do not edit here.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
CHANGE_TOOLS = EDIT_TOOLS | {"Bash"}
CHECKS_FAILING = (
    "The agent-kit checks fail (.agents/kit/check.sh). Fix what they name "
    "before ending the turn:\n{failures}"
)
REMINDER = (
    "Docs step: this turn changed code ({files}) but no Markdown file. If it "
    "changed a default, env var, path, interface or behaviour, update the "
    "nearest README / AGENTS.md now; run the lineage skill for a decision or "
    "experiment result{learning}. If no doc needs to change, say so in one line."
)


def read_config(repo: Path) -> dict[str, str]:
    """KEY="value" lines of .agents/agent-kit.conf."""
    config = {}
    path = repo / ".agents" / "agent-kit.conf"
    for line in path.read_text().splitlines() if path.exists() else []:
        match = re.match(r'^([A-Z_]+)="?([^"]*)"?\s*$', line.strip())
        if match:
            config[match.group(1)] = match.group(2)
    return config


def is_user_prompt(entry: dict) -> bool:
    content = (entry.get("message") or {}).get("content")
    if entry.get("type") != "user":
        return False
    if isinstance(content, str):
        return True
    return isinstance(content, list) and not any(
        isinstance(block, dict) and block.get("type") == "tool_result" for block in content)


def tool_calls_this_turn(transcript: Path) -> list[dict]:
    calls: list[dict] = []
    for line in transcript.read_text().splitlines():
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if is_user_prompt(entry):
            calls = []
        content = (entry.get("message") or {}).get("content")
        if entry.get("type") == "assistant" and isinstance(content, list):
            calls += [block for block in content
                      if isinstance(block, dict) and block.get("type") == "tool_use"]
    return calls


def edited_files(calls: list[dict]) -> list[Path]:
    paths = [(call.get("input") or {}).get("file_path") or (call.get("input") or {}).get(
        "notebook_path") for call in calls if call.get("name") in EDIT_TOOLS]
    return [Path(path) for path in paths if path]


def failing_checks(repo: Path) -> str:
    """Output of check.sh when it fails, else an empty string."""
    try:
        run = subprocess.run(["sh", ".agents/kit/check.sh", "--quiet"], cwd=repo,
                             capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return ""  # a missing shell or a hung run must not trap the agent
    return run.stdout[:3000] if run.returncode else ""


def repo_root(cwd: str) -> Path:
    found = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True).stdout.strip()
    return Path(found or cwd).resolve()


def main() -> None:
    event = json.load(sys.stdin)
    if event.get("stop_hook_active") or not event.get("transcript_path"):
        return
    repo = repo_root(event.get("cwd") or ".")
    config = read_config(repo)
    calls = tool_calls_this_turn(Path(event["transcript_path"]))
    if any(call.get("name") in CHANGE_TOOLS for call in calls):
        failures = failing_checks(repo)
        if failures:
            print(json.dumps({"decision": "block", "reason": CHECKS_FAILING.format(failures=failures)}))
            return
    skip = set(config.get("SKIP_DIRS", "").split()) | {config.get("LEARNING_DIR", "")}
    # Resolve symlinks first: /var/x and /private/var/x are the same file.
    resolved = [path.resolve() for path in edited_files(calls) if path.is_absolute()]
    files = [path for path in resolved if str(path).startswith(str(repo) + "/")
             and not skip & set(path.relative_to(repo).parts)]
    if any(path.suffix == ".md" for path in files):
        return
    extensions = {"." + ext for ext in config.get("CODE_EXTENSIONS", "").split()}
    code = sorted({str(path.relative_to(repo)) for path in files if path.suffix in extensions})
    if code:
        shown = ", ".join(code[:4]) + (" ..." if len(code) > 4 else "")
        learning = config.get("LEARNING_DIR", "")
        hint = (f"; if `{learning}/` explains this code, refresh it with the learning-docs skill"
                if learning and (repo / learning).is_dir() else "")
        print(json.dumps({"decision": "block", "reason": REMINDER.format(files=shown, learning=hint)}))


if __name__ == "__main__":
    try:
        main()
    except Exception:  # noqa: BLE001 - a broken hook must never block the agent
        pass
