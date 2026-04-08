from __future__ import annotations

from collections.abc import Sequence

from common import CONFIG_PATH, configured_project_name, python_executable, resolve_tool_path, run_command


def main(argv: Sequence[str] | None = None) -> int:
    del argv
    tools = [
        ("python", python_executable()),
        ("cmake", resolve_tool_path("CMAKE", ["cmake"], "CMake")),
        ("ninja", resolve_tool_path("NINJA", ["ninja"], "Ninja")),
        ("arm-none-eabi-gcc", resolve_tool_path("ARM_NONE_EABI_GCC", ["arm-none-eabi-gcc"], "GNU Arm Embedded GCC")),
        ("arm-none-eabi-objcopy", resolve_tool_path("ARM_NONE_EABI_OBJCOPY", ["arm-none-eabi-objcopy"], "GNU Arm Embedded objcopy")),
        ("arm-none-eabi-size", resolve_tool_path("ARM_NONE_EABI_SIZE", ["arm-none-eabi-size"], "GNU Arm Embedded size")),
        ("clang-format", resolve_tool_path("CLANG_FORMAT", ["clang-format"], "clang-format")),
        ("cppcheck", resolve_tool_path("CPPCHECK", ["cppcheck"], "cppcheck")),
        ("git", resolve_tool_path("GIT", ["git"], "Git")),
        ("lefthook", resolve_tool_path("LEFTHOOK", ["lefthook"], "lefthook")),
    ]

    print(f"[init] Local CI config: {CONFIG_PATH}")
    print(f"[init] Project name   : {configured_project_name()}")
    print("[init] Toolchain check passed:")
    for name, path in tools:
        print(f"  {name:<20} {path}")

    optional_openocd = None
    try:
        optional_openocd = resolve_tool_path("OPENOCD", ["openocd"], "OpenOCD")
    except Exception:
        optional_openocd = None

    if optional_openocd:
        print(f"  {'openocd':<20} {optional_openocd}")
    else:
        print("  openocd              optional (required for flash only)")

    lefthook = dict(tools)["lefthook"]
    print("[init] Installing git hooks via lefthook...")
    run_command([lefthook, "install"])
    print("[init] Local CI bootstrap complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
