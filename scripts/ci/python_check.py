from __future__ import annotations

import argparse
import py_compile
import re
from collections.abc import Sequence
from pathlib import Path

from common import (
    normalize_repo_path,
    print_error,
    print_info,
    print_section,
    print_summary,
    print_warning,
    relative_repo_path,
    repo_root,
)


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
        print_warning("[python-check] No Python files found. Skipping.")
        return 0

    print_section("python-check")
    print_info(f"[python-check] Validating {len(files)} Python file(s).")
    for path in files:
        if not path.is_file():
            continue
        try:
            py_compile.compile(str(path), doraise=True)
        except py_compile.PyCompileError as exc:
            match = re.search(r'File\s+"(?P<path>[^"]+)",\s+line\s+(?P<line>\d+)', exc.msg)
            print_error("[error] stage=python-check")
            print_error(f"[error] file={relative_repo_path(path)}")
            if match:
                print_error(f"[error] line={match.group('line')}")
            message = exc.exc_value or exc.msg.strip()
            print_error(f"[error] message={message}")
            raise RuntimeError(f"Python syntax validation failed for '{relative_repo_path(path)}'.") from exc

    print_summary("[python-check] Python syntax validation completed successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
