from __future__ import annotations

import argparse
from collections.abc import Sequence

from common import size_summary


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preset", choices=["Debug", "Release"], default="Debug")
    args = parser.parse_args(argv)

    summary = size_summary(args.preset)
    print("[size] Raw tool output:")
    for line in summary["lines"]:
        print(line)

    print("")
    print("[size] Summary:")
    print(f"  preset : {summary['preset']}")
    print(f"  elf    : {summary['elf']}")
    print(f"  text   : {summary['text']} B")
    print(f"  data   : {summary['data']} B")
    print(f"  bss    : {summary['bss']} B")
    print(f"  dec    : {summary['dec']} B")
    print(f"  hex    : {summary['hex']}")
    print(f"  flash  : {summary['flash']} B")
    print(f"  ram    : {summary['ram']} B")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
