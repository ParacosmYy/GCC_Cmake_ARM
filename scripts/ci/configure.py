from __future__ import annotations

import argparse
from collections.abc import Sequence

from common import cmake_configure


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preset", choices=["All", "Debug", "Release"], default="All")
    args = parser.parse_args(argv)

    presets = ["Debug", "Release"] if args.preset == "All" else [args.preset]
    for preset in presets:
        cmake_configure(preset)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
