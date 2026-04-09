from __future__ import annotations

import argparse
from collections.abc import Sequence

from common import (
    assert_expected_artifacts_exist,
    cmake_build,
    cmake_configure,
    ensure_firmware_artifacts,
    print_section,
    print_summary,
)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preset", choices=["Debug", "Release"], default="Debug")
    args = parser.parse_args(argv)

    print_section(f"build :: {args.preset}")
    cmake_configure(args.preset)
    cmake_build(args.preset)
    ensure_firmware_artifacts(args.preset)
    assert_expected_artifacts_exist(args.preset)
    print_summary(f"[build] {args.preset} completed successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
