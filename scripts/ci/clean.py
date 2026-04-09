from __future__ import annotations

from collections.abc import Sequence

from common import clean_build_directories, print_section, print_summary


def main(argv: Sequence[str] | None = None) -> int:
    del argv
    print_section("clean")
    clean_build_directories()
    print_summary("[clean] Clean completed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
