from __future__ import annotations

import argparse
from collections.abc import Sequence

from common import assert_expected_artifacts_exist, cmake_build, cmake_configure, ensure_firmware_artifacts


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preset", choices=["Debug", "Release"], default="Debug")
    args = parser.parse_args(argv)

    cmake_configure(args.preset)
    cmake_build(args.preset)
    ensure_firmware_artifacts(args.preset)
    assert_expected_artifacts_exist(args.preset)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
