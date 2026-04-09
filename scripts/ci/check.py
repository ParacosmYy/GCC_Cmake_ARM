from __future__ import annotations

import argparse
import time
from collections.abc import Sequence

import build as build_cmd
import format as format_cmd
import lint as lint_cmd
import python_check as python_check_cmd
import size as size_cmd
from common import format_duration, print_error, print_section, print_success, print_summary, timed_call


def run_step(label: str, fn, *args: str) -> None:
    print_section(f"check :: {label}")
    try:
        _, elapsed = timed_call(fn, list(args))
    except Exception as exc:
        print_error(f"[check] {label} failed: {exc}")
        raise
    print_success(f"[check] {label} completed in {format_duration(elapsed)}")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["local", "full"], default="local")
    args = parser.parse_args(argv)

    total_start = time.perf_counter()
    print_section("Local CI Check")
    print_success(f"[check] Mode: {args.mode}")
    run_step("format-check", format_cmd.main, "--check")
    lint_mode = "auto" if args.mode == "local" else "full"
    run_step(f"lint ({lint_mode})", lint_cmd.main, "--mode", lint_mode)
    run_step("python-check", python_check_cmd.main)
    run_step("build Debug", build_cmd.main, "--preset", "Debug")
    run_step("build Release", build_cmd.main, "--preset", "Release")
    run_step("size Debug", size_cmd.main, "--preset", "Debug")
    total_elapsed = time.perf_counter() - total_start
    print_summary(f"[check] Local CI completed successfully in {format_duration(total_elapsed)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
