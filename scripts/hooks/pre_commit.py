from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))

from common import (  # noqa: E402
    is_handmaintained_format_path,
    is_json_validation_path,
    normalize_repo_path,
    python_executable,
    relative_repo_path,
    repo_root,
    resolve_tool_path,
    run_command,
    staged_files,
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    print("[pre-commit] Checking staged diff for whitespace issues and conflict markers...")
    diff_check = run_command(["git", "diff", "--cached", "--check"], check=False, capture_output=True)
    if diff_check.returncode != 0:
        if diff_check.stdout:
            print(diff_check.stdout, end="")
        if diff_check.stderr:
            print(diff_check.stderr, end="", file=sys.stderr)
        raise RuntimeError("Staged changes contain whitespace errors or conflict markers.")

    staged = staged_files()
    if not staged:
        print("[pre-commit] No staged files detected. Skipping quick checks.")
        return 0

    format_candidates = [item for item in staged if is_handmaintained_format_path(normalize_repo_path(item))]
    json_candidates = [item for item in staged if is_json_validation_path(normalize_repo_path(item))]
    python_candidates = [
        item
        for item in staged
        if normalize_repo_path(item).startswith("Scripts/") and normalize_repo_path(item).endswith(".py")
    ]
    clang_format = None

    for item in format_candidates:
        unstaged = run_command(["git", "diff", "--name-only", "--", item], capture_output=True)
        changed = [line for line in unstaged.stdout.splitlines() if line.strip()]
        if changed:
            raise RuntimeError(f"File '{item}' has unstaged changes. Please stage or stash the whole file before auto-formatting.")

    for item in json_candidates:
        absolute = repo_root() / item
        print(f"[pre-commit] Validating JSON: {item}")
        json.loads(absolute.read_text(encoding="utf-8"))

    if python_candidates:
        print("[pre-commit] Validating staged Python scripts...")
        run_command([python_executable(), str(CI_DIR / "python_check.py"), *python_candidates])

    formatted: list[str] = []
    for item in format_candidates:
        if clang_format is None:
            clang_format = resolve_tool_path("CLANG_FORMAT", ["clang-format"], "clang-format")
        absolute = repo_root() / item
        if not absolute.is_file():
            continue

        before_hash = sha256(absolute)
        run_command([clang_format, "-i", "--style=file", str(absolute)])
        after_hash = sha256(absolute)

        if before_hash != after_hash:
            formatted.append(item)
            run_command(["git", "add", "--", item])

    for item in format_candidates:
        if clang_format is None:
            clang_format = resolve_tool_path("CLANG_FORMAT", ["clang-format"], "clang-format")
        absolute = repo_root() / item
        if not absolute.is_file():
            continue
        try:
            run_command([clang_format, "--dry-run", "--Werror", "--style=file", str(absolute)])
        except Exception as exc:
            raise RuntimeError(f"Formatting verification failed for '{relative_repo_path(absolute)}'. Please review the file and try again.") from exc

    if formatted:
        print("[pre-commit] Auto-formatted and re-staged hand-maintained files:")
        for item in formatted:
            print(f"  - {item}")
    else:
        print("[pre-commit] No staged hand-maintained files required formatting.")

    print("[pre-commit] Quick checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
