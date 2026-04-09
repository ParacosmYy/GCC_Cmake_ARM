from __future__ import annotations

import argparse
from collections.abc import Sequence

from common import (
    handmaintained_format_files,
    print_failure_summary,
    print_info,
    print_section,
    print_success,
    print_summary,
    print_warning,
    relative_repo_path,
    resolve_tool_path,
    run_command,
)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)

    files = handmaintained_format_files()
    if not files:
        print_warning("[format] No hand-maintained source files found. Skipping.")
        return 0

    clang_format = resolve_tool_path("CLANG_FORMAT", ["clang-format"], "clang-format")
    mode = "check" if args.check else "format"
    print_section(f"format :: {mode}")
    print_info(f"[format] Running {mode} on {len(files)} file(s).")

    for path in files:
        relative = relative_repo_path(path)
        if args.check:
            command = [clang_format, "--dry-run", "--Werror", "--style=file", str(path)]
            try:
                run_command(command, capture_output=True)
            except Exception as exc:
                if hasattr(exc, "stdout") or hasattr(exc, "stderr"):
                    print_failure_summary(
                        "format-check",
                        stdout=getattr(exc, "stdout", None),
                        stderr=getattr(exc, "stderr", None),
                        command=command,
                    )
                raise RuntimeError(f"Formatting verification failed for '{relative}'.") from exc
        else:
            command = [clang_format, "-i", "--style=file", str(path)]
            try:
                run_command(command, capture_output=True)
            except Exception as exc:
                if hasattr(exc, "stdout") or hasattr(exc, "stderr"):
                    print_failure_summary(
                        "format",
                        stdout=getattr(exc, "stdout", None),
                        stderr=getattr(exc, "stderr", None),
                        command=command,
                    )
                raise RuntimeError(f"clang-format failed for '{relative}'.") from exc

    print_summary(f"[format] Completed {mode} successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
