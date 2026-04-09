from __future__ import annotations

import sys
from pathlib import Path


CI_DIR = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI_DIR))

from common import python_executable, run_command  # noqa: E402


def main() -> int:
    print("[pre-push] Running optional full local CI via Scripts/ci/main.py check --full...")
    run_command([python_executable(), str(CI_DIR / "main.py"), "check", "--full"])
    print("[pre-push] Full local CI passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
