from __future__ import annotations

import argparse
from collections.abc import Sequence

from common import artifact_path, flash_config_value, resolve_openocd_config, resolve_tool_path, run_command


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preset", choices=["Debug", "Release"])
    args = parser.parse_args(argv)

    preset = args.preset or flash_config_value("default_preset", "Debug")
    openocd = resolve_tool_path("OPENOCD", ["openocd"], "OpenOCD")
    elf = artifact_path(preset, "elf")
    if not elf.is_file():
        raise RuntimeError(f"ELF not found for preset '{preset}': {elf}. Run the matching build first.")

    interface_cfg = resolve_openocd_config(
        openocd,
        "OPENOCD_INTERFACE_CFG",
        flash_config_value("interface_cfg"),
        "OpenOCD interface config",
    )
    target_cfg = resolve_openocd_config(
        openocd,
        "OPENOCD_TARGET_CFG",
        flash_config_value("target_cfg"),
        "OpenOCD target config",
    )

    print(f"[flash] Flashing {elf}")
    run_command([openocd, "-f", interface_cfg, "-f", target_cfg, "-c", f"program {elf} verify reset exit"])
    print("[flash] Flash completed successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
