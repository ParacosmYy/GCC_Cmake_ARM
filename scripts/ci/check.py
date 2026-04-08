from __future__ import annotations

from collections.abc import Sequence

import build as build_cmd
import format as format_cmd
import lint as lint_cmd
import size as size_cmd


def main(argv: Sequence[str] | None = None) -> int:
    del argv
    print("[check] format-check")
    format_cmd.main(["--check"])
    print("[check] lint")
    lint_cmd.main()
    print("[check] build Debug")
    build_cmd.main(["--preset", "Debug"])
    print("[check] build Release")
    build_cmd.main(["--preset", "Release"])
    print("[check] size Debug")
    size_cmd.main(["--preset", "Debug"])
    print("[check] Local CI completed successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
