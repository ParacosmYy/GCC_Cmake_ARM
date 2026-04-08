from __future__ import annotations

import argparse
from collections.abc import Sequence

from common import handmaintained_format_files, relative_repo_path, resolve_tool_path, run_command


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)

    files = handmaintained_format_files()
    if not files:
        print("[format] No hand-maintained source files found. Skipping.")
        return 0

    clang_format = resolve_tool_path("CLANG_FORMAT", ["clang-format"], "clang-format")
    mode = "check" if args.check else "format"
    print(f"[format] Running {mode} on {len(files)} file(s).")

    for path in files:
        relative = relative_repo_path(path)
        if args.check:
            try:
                run_command([clang_format, "--dry-run", "--Werror", "--style=file", str(path)])
            except Exception as exc:
                raise RuntimeError(f"Formatting verification failed for '{relative}'.") from exc
        else:
            try:
                run_command([clang_format, "-i", "--style=file", str(path)])
            except Exception as exc:
                raise RuntimeError(f"clang-format failed for '{relative}'.") from exc

    print(f"[format] Completed {mode} successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
