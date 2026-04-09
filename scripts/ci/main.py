from __future__ import annotations

import argparse
import os
import subprocess

import build as build_cmd
import check as check_cmd
import clean as clean_cmd
import configure as configure_cmd
import flash as flash_cmd
import format as format_cmd
import init as init_cmd
import lint as lint_cmd
import size as size_cmd
from common import print_error, print_failure_summary, print_section


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Unified local CI entrypoint for enterprise-standard local and cloud workflows."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("init", help="Validate required tools and install git hooks.")

    configure_parser = subparsers.add_parser("configure", help="Configure build directories.")
    configure_parser.add_argument("--preset", choices=["All", "Debug", "Release"], default="All")

    build_parser = subparsers.add_parser("build", help="Configure and build firmware.")
    build_parser.add_argument("--preset", choices=["Debug", "Release"], default="Debug")

    format_parser = subparsers.add_parser("format", help="Format hand-maintained source files.")
    format_parser.add_argument("--check", action="store_true", help="Verify formatting without modifying files.")

    subparsers.add_parser("lint", help="Run static analysis on hand-maintained source files.")

    size_parser = subparsers.add_parser("size", help="Print firmware size summary.")
    size_parser.add_argument("--preset", choices=["Debug", "Release"], default="Debug")

    lint_parser = subparsers.choices["lint"]
    lint_parser.add_argument("--mode", choices=["auto", "changed", "full"], default="auto")

    check_parser = subparsers.add_parser("check", help="Run the full local quality gate.")
    check_parser.add_argument("--mode", choices=["local", "full"], default="local")

    flash_parser = subparsers.add_parser("flash", help="Flash the firmware with OpenOCD.")
    flash_parser.add_argument("--preset", choices=["Debug", "Release"])

    subparsers.add_parser("clean", help="Remove local build output.")

    args = parser.parse_args()

    try:
        if args.command == "init":
            return init_cmd.main()
        if args.command == "configure":
            return configure_cmd.main(["--preset", args.preset])
        if args.command == "build":
            return build_cmd.main(["--preset", args.preset])
        if args.command == "format":
            forwarded_args: list[str] = []
            if args.check:
                forwarded_args.append("--check")
            return format_cmd.main(forwarded_args)
        if args.command == "lint":
            return lint_cmd.main(["--mode", args.mode])
        if args.command == "size":
            return size_cmd.main(["--preset", args.preset])
        if args.command == "check":
            return check_cmd.main(["--mode", args.mode])
        if args.command == "flash":
            forwarded_args = []
            if args.preset:
                forwarded_args.extend(["--preset", args.preset])
            return flash_cmd.main(forwarded_args)
        if args.command == "clean":
            return clean_cmd.main()
    except Exception as exc:
        print_section("Local CI Failed")
        if isinstance(exc, subprocess.CalledProcessError):
            print_failure_summary(
                args.command,
                stdout=exc.stdout,
                stderr=exc.stderr,
                command=exc.cmd if isinstance(exc.cmd, (list, tuple)) else None,
            )
        print_error(f"[ci] Command '{args.command}' failed: {exc}")
        if os.environ.get("LOCAL_CI_TRACEBACK") == "1":
            raise
        return 1

    raise RuntimeError(f"Unsupported command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
