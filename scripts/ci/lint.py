from __future__ import annotations

import argparse
import time
from collections.abc import Sequence

from common import (
    build_dir,
    changed_repo_paths,
    changed_handmaintained_lint_files,
    cmake_configure,
    format_duration,
    handmaintained_lint_files,
    print_failure_summary,
    print_error,
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
    parser.add_argument("--mode", choices=["auto", "changed", "full"], default="auto")
    args = parser.parse_args(argv)

    cppcheck = resolve_tool_path("CPPCHECK", ["cppcheck"], "cppcheck")
    cmake_configure("Debug")
    compile_commands = build_dir("Debug") / "compile_commands.json"
    if not compile_commands.is_file():
        raise RuntimeError(f"compile_commands.json not found: {compile_commands}")

    changed_files = changed_handmaintained_lint_files()
    changed_paths = changed_repo_paths()
    if args.mode == "full":
        files = handmaintained_lint_files()
        selected_mode = "full"
    elif args.mode == "changed":
        files = changed_files
        selected_mode = "changed"
    else:
        if changed_files:
            files = changed_files
            selected_mode = "changed"
        elif changed_paths:
            files = []
            selected_mode = "skip"
        else:
            files = handmaintained_lint_files()
            selected_mode = "full"

    if not files:
        if selected_mode == "skip":
            print_warning("[lint] No changed hand-maintained C/C++ sources detected. Skipping local lint.")
        else:
            print_warning(f"[lint] No hand-maintained C/C++ sources found for mode '{selected_mode}'. Skipping.")
        return 0

    total_start = time.perf_counter()
    print_section("lint")
    print_info(f"[lint] Mode: {selected_mode}")
    print_info(f"[lint] Running cppcheck on {len(files)} file(s).")
    for index, path in enumerate(files, start=1):
        relative = relative_repo_path(path)
        file_start = time.perf_counter()
        print_info(f"[lint] ({index}/{len(files)}) {relative}")
        try:
            command = [
                cppcheck,
                f"--project={compile_commands}",
                f"--file-filter=*{relative}",
                "--template=gcc",
                "--enable=warning,style,performance,portability",
                "--inline-suppr",
                "--force",
                "--quiet",
                "--std=c11",
                "--suppress=missingIncludeSystem",
                "--suppress=constParameterPointer",
                "--suppress=*:*Drivers/*",
                "--suppress=*:*Middlewares/*",
                "--error-exitcode=1",
            ]
            run_command(
                command,
                capture_output=True,
            )
        except Exception as exc:
            if hasattr(exc, "stdout") or hasattr(exc, "stderr"):
                print_failure_summary(
                    "lint",
                    stdout=getattr(exc, "stdout", None),
                    stderr=getattr(exc, "stderr", None),
                    command=command,
                )
            print_error(f"[lint] Failed on {relative}")
            raise RuntimeError(f"cppcheck failed for '{relative}'.") from exc
        elapsed = time.perf_counter() - file_start
        print_success(f"[lint] Completed {relative} in {format_duration(elapsed)}")

    total_elapsed = time.perf_counter() - total_start
    print_summary(f"[lint] Static analysis completed successfully in {format_duration(total_elapsed)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
