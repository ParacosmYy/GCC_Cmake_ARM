from __future__ import annotations

import argparse
import time
from collections.abc import Sequence

import build as build_cmd
import format as format_cmd
import lint as lint_cmd
import python_check as python_check_cmd
import size as size_cmd


def run_step(label: str, fn, *args: str) -> None:
    print(f"[check] {label}")
    start = time.perf_counter()
    fn(list(args))
    elapsed = time.perf_counter() - start
    print(f"[check] {label} completed in {elapsed:.2f}s")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["local", "full"], default="local")
    args = parser.parse_args(argv)

    total_start = time.perf_counter()
    print(f"[check] Mode: {args.mode}")
    run_step("format-check", format_cmd.main, "--check")
    lint_mode = "auto" if args.mode == "local" else "full"
    run_step(f"lint ({lint_mode})", lint_cmd.main, "--mode", lint_mode)
    run_step("python-check", python_check_cmd.main)
    run_step("build Debug", build_cmd.main, "--preset", "Debug")
    run_step("build Release", build_cmd.main, "--preset", "Release")
    run_step("size Debug", size_cmd.main, "--preset", "Debug")
    total_elapsed = time.perf_counter() - total_start
    print(f"[check] Local CI completed successfully in {total_elapsed:.2f}s.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
