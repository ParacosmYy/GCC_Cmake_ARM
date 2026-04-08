from __future__ import annotations

from collections.abc import Sequence

from common import clean_build_directories


def main(argv: Sequence[str] | None = None) -> int:
    del argv
    clean_build_directories()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
