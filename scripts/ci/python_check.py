from __future__ import annotations

import argparse
import py_compile
from collections.abc import Sequence
from pathlib import Path

from common import normalize_repo_path, relative_repo_path, repo_root


def candidate_files() -> list[Path]:
    matches: list[Path] = []
    for path in (repo_root() / "Scripts").rglob("*.py"):
        normalized = normalize_repo_path(path.relative_to(repo_root()))
        if "__pycache__/" in normalized:
            continue
        if path.is_file():
            matches.append(path)
    return sorted(matches)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args(argv)

    if args.paths:
        files = [repo_root() / item for item in args.paths]
    else:
        files = candidate_files()

    if not files:
        print("[python-check] No Python files found. Skipping.")
        return 0

    print(f"[python-check] Validating {len(files)} Python file(s).")
    for path in files:
        if not path.is_file():
            continue
        try:
            py_compile.compile(str(path), doraise=True)
        except py_compile.PyCompileError as exc:
            raise RuntimeError(f"Python syntax validation failed for '{relative_repo_path(path)}'.") from exc

    print("[python-check] Python syntax validation completed successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
