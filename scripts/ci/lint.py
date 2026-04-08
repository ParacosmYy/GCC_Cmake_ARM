from __future__ import annotations

from collections.abc import Sequence

from common import build_dir, cmake_configure, handmaintained_lint_files, relative_repo_path, resolve_tool_path, run_command


def main(argv: Sequence[str] | None = None) -> int:
    del argv
    cppcheck = resolve_tool_path("CPPCHECK", ["cppcheck"], "cppcheck")
    compile_commands = build_dir("Debug") / "compile_commands.json"
    if not compile_commands.is_file():
        cmake_configure("Debug")

    files = handmaintained_lint_files()
    if not files:
        print("[lint] No hand-maintained C/C++ sources found. Skipping.")
        return 0

    print(f"[lint] Running cppcheck on {len(files)} file(s).")
    for path in files:
        relative = relative_repo_path(path)
        print(f"[lint] {relative}")
        try:
            run_command(
                [
                    cppcheck,
                    f"--project={compile_commands}",
                    f"--file-filter=*{relative}",
                    "--enable=warning,style,performance,portability",
                    "--inline-suppr",
                    "--force",
                    "--quiet",
                    "--std=c11",
                    "--suppress=missingIncludeSystem",
                    "--suppress=constParameterPointer",
                    "--suppress=*:*Drivers/*",
                    "--suppress=*:*Middlewares/*",
                    "--error-exitcode=1",
                ]
            )
        except Exception as exc:
            raise RuntimeError(f"cppcheck failed for '{relative}'.") from exc

    print("[lint] Static analysis completed successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
