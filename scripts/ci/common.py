from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = REPO_ROOT / ".local-ci" / "config.json"
ANSI_RESET = "\033[0m"
ANSI_COLORS = {
    "red": "\033[31m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "blue": "\033[34m",
    "magenta": "\033[35m",
    "cyan": "\033[36m",
    "bold": "\033[1m",
}
DIAGNOSTIC_PATTERNS = [
    re.compile(
        r'(?P<path>[A-Za-z]:[\\/][^\r\n:]+?|[^:\r\n]+?\.[A-Za-z0-9_]+):'
        r'(?P<line>\d+):(?P<column>\d+):\s*(?:(?P<severity>fatal error|error|warning|note):\s*)?(?P<message>[^\r\n]+)'
    ),
    re.compile(
        r'(?P<path>[A-Za-z]:[\\/][^\r\n:]+?|[^:\r\n]+?\.[A-Za-z0-9_]+):'
        r'(?P<line>\d+):\s*(?:(?P<severity>fatal error|error|warning|note):\s*)?(?P<message>[^\r\n]+)'
    ),
    re.compile(
        r'File\s+"(?P<path>[^"]+)",\s+line\s+(?P<line>\d+)(?:,\s+in\s+[^\r\n]+)?\s*\r?\n(?P<message>[^\r\n]+)'
    ),
]


def _enable_windows_virtual_terminal() -> None:
    if os.name != "nt":
        return
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        handle = kernel32.GetStdHandle(-11)
        if handle == 0:
            return
        mode = ctypes.c_uint32()
        if kernel32.GetConsoleMode(handle, ctypes.byref(mode)) == 0:
            return
        kernel32.SetConsoleMode(handle, mode.value | 0x0004)
    except Exception:
        return


_enable_windows_virtual_terminal()


def repo_root() -> Path:
    return REPO_ROOT


def load_config() -> dict[str, Any]:
    if not CONFIG_PATH.is_file():
        raise RuntimeError(f"Local CI config not found: {CONFIG_PATH}")
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def run_command(
    command: list[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    capture_output: bool = False,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=str(cwd or repo_root()),
        check=False,
        capture_output=capture_output,
        text=True,
    )
    if check and result.returncode != 0:
        if result.stdout:
            print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        raise subprocess.CalledProcessError(result.returncode, command, result.stdout, result.stderr)
    return result


def supports_color() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("FORCE_COLOR"):
        return True
    return sys.stdout.isatty()


def colorize(text: str, color: str) -> str:
    if not supports_color() or color not in ANSI_COLORS:
        return text
    return f"{ANSI_COLORS[color]}{text}{ANSI_RESET}"


def print_line(message: str = "") -> None:
    print(message, flush=True)


def print_info(message: str) -> None:
    print_line(colorize(message, "cyan"))


def print_success(message: str) -> None:
    print_line(colorize(message, "green"))


def print_warning(message: str) -> None:
    print_line(colorize(message, "yellow"))


def print_error(message: str) -> None:
    print_line(colorize(message, "red"))


def print_section(title: str) -> None:
    line = f"== {title} =="
    print_line(colorize(line, "blue"))


def print_summary(message: str) -> None:
    print_line(colorize(message, "bold"))


def format_duration(seconds: float) -> str:
    if seconds < 1:
        return f"{seconds * 1000:.0f}ms"
    return f"{seconds:.2f}s"


def timed_call(fn, *args, **kwargs):
    start = time.perf_counter()
    result = fn(*args, **kwargs)
    return result, time.perf_counter() - start


def format_command(command: Iterable[str]) -> str:
    parts = [str(item) for item in command]
    return subprocess.list2cmdline(parts) if os.name == "nt" else " ".join(parts)


def combine_process_output(stdout: str | None, stderr: str | None) -> str:
    sections = [text for text in (stdout, stderr) if text]
    return "\n".join(sections)


def diagnostic_path(path_text: str) -> str:
    path_text = path_text.strip().strip('"').replace("\\", "/")
    candidate = Path(path_text)
    if candidate.is_absolute():
        try:
            return relative_repo_path(candidate)
        except Exception:
            return normalize_repo_path(path_text)
    return normalize_repo_path(path_text)


def first_diagnostic(text: str) -> dict[str, str] | None:
    for pattern in DIAGNOSTIC_PATTERNS:
        match = pattern.search(text)
        if not match:
            continue
        groups = {key: (value or "").strip() for key, value in match.groupdict().items()}
        groups["path"] = diagnostic_path(groups["path"])
        return groups
    return None


def print_failure_summary(
    stage: str,
    *,
    stdout: str | None = None,
    stderr: str | None = None,
    command: Iterable[str] | None = None,
) -> None:
    print_error(f"[error] stage={stage}")
    if command:
        print_error(f"[error] command={format_command(command)}")

    diagnostic = first_diagnostic(combine_process_output(stdout, stderr))
    if not diagnostic:
        return

    print_error(f"[error] file={diagnostic['path']}")
    if diagnostic.get("line") and diagnostic.get("column"):
        print_error(f"[error] location={diagnostic['line']}:{diagnostic['column']}")
    elif diagnostic.get("line"):
        print_error(f"[error] line={diagnostic['line']}")

    if diagnostic.get("severity"):
        print_error(f"[error] severity={diagnostic['severity']}")
    if diagnostic.get("message"):
        print_error(f"[error] message={diagnostic['message']}")


def get_optional(mapping: dict[str, Any] | None, key: str, default: Any = None) -> Any:
    if mapping is None:
        return default
    value = mapping.get(key, default)
    return default if value is None else value


def normalize_repo_path(path: str | Path) -> str:
    value = str(path).replace("\\", "/")
    while value.startswith("./"):
        value = value[2:]
    return value.lstrip("/")


def relative_repo_path(path: str | Path) -> str:
    absolute = Path(path).resolve()
    return normalize_repo_path(absolute.relative_to(repo_root()))


def resolve_tool_path(env_var: str, command_names: Iterable[str], description: str) -> str:
    env_value = os.environ.get(env_var, "").strip().strip('"')
    if env_value:
        expanded = os.path.expanduser(env_value)
        if Path(expanded).exists():
            return str(Path(expanded).resolve())
        located = shutil.which(env_value)
        if located:
            return located
        raise RuntimeError(f"{description} not found via {env_var}={env_value}.")

    for command_name in command_names:
        located = shutil.which(command_name)
        if located:
            return located

    choices = ", ".join(command_names)
    raise RuntimeError(f"{description} not found. Set {env_var} or add one of these commands to PATH: {choices}")


def project_name_from_cmakelists() -> str:
    cmake_lists = (repo_root() / "CMakeLists.txt").read_text(encoding="utf-8")
    match = re.search(r"set\s*\(\s*CMAKE_PROJECT_NAME\s+([A-Za-z0-9_]+)\s*\)", cmake_lists)
    if not match:
        match = re.search(r"project\s*\(\s*([A-Za-z0-9_]+)", cmake_lists)
    if not match:
        raise RuntimeError("Unable to determine project name from CMakeLists.txt.")
    return match.group(1)


def configured_project_name() -> str:
    config = load_config()
    project = get_optional(config, "project", {})
    return get_optional(project, "name", project_name_from_cmakelists())


def build_config() -> dict[str, Any]:
    return get_optional(load_config(), "build", {})


def logical_preset_name(preset: str) -> str:
    presets = get_optional(build_config(), "presets", {})
    return get_optional(presets, preset.lower(), preset)


def build_root() -> str:
    return normalize_repo_path(get_optional(build_config(), "root", "build"))


def build_dir(preset: str) -> Path:
    return repo_root() / build_root() / logical_preset_name(preset)


def artifact_base_name() -> str:
    artifacts = get_optional(load_config(), "artifacts", {})
    return get_optional(artifacts, "base_name", configured_project_name())


def artifact_path(preset: str, extension: str) -> Path:
    return build_dir(preset) / f"{artifact_base_name()}.{extension}"


def generated_artifact_extensions() -> list[str]:
    artifacts = get_optional(load_config(), "artifacts", {})
    formats = list(get_optional(artifacts, "generated_formats", ["bin", "hex"]))
    return [item for item in formats if item in {"bin", "hex"}]


def expected_artifact_extensions() -> list[str]:
    return ["elf", "map", *generated_artifact_extensions()]


def glob_to_regex(pattern: str) -> re.Pattern[str]:
    normalized = normalize_repo_path(pattern)
    parts: list[str] = ["^"]
    index = 0
    while index < len(normalized):
        if normalized[index : index + 3] == "**/":
            parts.append("(?:.*/)?")
            index += 3
            continue
        if normalized[index : index + 2] == "**":
            parts.append(".*")
            index += 2
            continue

        char = normalized[index]
        if char == "*":
            parts.append("[^/]*")
        elif char == "?":
            parts.append("[^/]")
        else:
            parts.append(re.escape(char))
        index += 1

    parts.append("$")
    return re.compile("".join(parts))


def matches_any_pattern(repo_relative_path: str, patterns: Iterable[str]) -> bool:
    normalized = normalize_repo_path(repo_relative_path)
    return any(glob_to_regex(pattern).match(normalized) for pattern in patterns)


def repo_candidate_paths() -> list[str]:
    result = run_command(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "--full-name", "--"],
        capture_output=True,
    )
    paths = [normalize_repo_path(line) for line in result.stdout.splitlines() if line.strip()]
    return sorted(set(paths))


def git_has_head() -> bool:
    result = run_command(["git", "rev-parse", "--verify", "HEAD"], check=False, capture_output=True)
    return result.returncode == 0


def changed_repo_paths() -> list[str]:
    if not git_has_head():
        return repo_candidate_paths()

    tracked = run_command(
        ["git", "diff", "--name-only", "--diff-filter=ACMR", "HEAD", "--"],
        capture_output=True,
    )
    untracked = run_command(
        ["git", "ls-files", "--others", "--exclude-standard", "--full-name", "--"],
        capture_output=True,
    )

    paths = [normalize_repo_path(line) for line in tracked.stdout.splitlines() if line.strip()]
    paths.extend(normalize_repo_path(line) for line in untracked.stdout.splitlines() if line.strip())
    return sorted(set(paths))


def quality_scope_config(scope: str) -> dict[str, Any]:
    quality = get_optional(load_config(), "quality", {})
    return get_optional(quality, scope, {})


def quality_patterns(scope: str, kind: str) -> list[str]:
    patterns = get_optional(quality_scope_config(scope), kind, [])
    return [normalize_repo_path(item) for item in patterns if str(item).strip()]


def managed_repo_paths(scope: str) -> list[str]:
    include_patterns = quality_patterns(scope, "include")
    exclude_patterns = quality_patterns(scope, "exclude")
    if not include_patterns:
        return []

    matches: list[str] = []
    for candidate in repo_candidate_paths():
        if not matches_any_pattern(candidate, include_patterns):
            continue
        if exclude_patterns and matches_any_pattern(candidate, exclude_patterns):
            continue
        candidate_path = repo_root() / candidate
        if candidate_path.is_file():
            matches.append(candidate)
    return sorted(set(matches))


def changed_managed_repo_paths(scope: str) -> list[str]:
    include_patterns = quality_patterns(scope, "include")
    exclude_patterns = quality_patterns(scope, "exclude")
    if not include_patterns:
        return []

    matches: list[str] = []
    for candidate in changed_repo_paths():
        if not matches_any_pattern(candidate, include_patterns):
            continue
        if exclude_patterns and matches_any_pattern(candidate, exclude_patterns):
            continue
        candidate_path = repo_root() / candidate
        if candidate_path.is_file():
            matches.append(candidate)
    return sorted(set(matches))


def handmaintained_format_files() -> list[Path]:
    return [repo_root() / item for item in managed_repo_paths("format")]


def handmaintained_lint_files() -> list[Path]:
    return [repo_root() / item for item in managed_repo_paths("lint")]


def changed_handmaintained_lint_files() -> list[Path]:
    return [repo_root() / item for item in changed_managed_repo_paths("lint")]


def is_handmaintained_format_path(repo_relative_path: str) -> bool:
    include_patterns = quality_patterns("format", "include")
    exclude_patterns = quality_patterns("format", "exclude")
    if not include_patterns or not matches_any_pattern(repo_relative_path, include_patterns):
        return False
    if exclude_patterns and matches_any_pattern(repo_relative_path, exclude_patterns):
        return False
    return True


def staged_files() -> list[str]:
    result = run_command(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "--"],
        capture_output=True,
    )
    return [line for line in result.stdout.splitlines() if line.strip()]


def json_validation_patterns() -> list[str]:
    hooks = get_optional(load_config(), "hooks", {})
    pre_commit = get_optional(hooks, "pre_commit", {})
    patterns = get_optional(pre_commit, "json_validate", ["CMakePresets.json", ".vscode/*.json", ".local-ci/*.json"])
    return [normalize_repo_path(item) for item in patterns if str(item).strip()]


def is_json_validation_path(repo_relative_path: str) -> bool:
    patterns = json_validation_patterns()
    return bool(patterns) and matches_any_pattern(repo_relative_path, patterns)


def cmake_configure(preset: str) -> None:
    cmake = resolve_tool_path("CMAKE", ["cmake"], "CMake")
    ninja = resolve_tool_path("NINJA", ["ninja"], "Ninja")
    actual_preset = logical_preset_name(preset)
    print_info(f"[configure] Preset: {preset} -> {actual_preset}")
    run_command([cmake, "--preset", actual_preset, f"-DCMAKE_MAKE_PROGRAM={ninja}"])


def cmake_build(preset: str) -> None:
    cmake = resolve_tool_path("CMAKE", ["cmake"], "CMake")
    actual_preset = logical_preset_name(preset)
    print_info(f"[build] Preset: {preset} -> {actual_preset}")
    run_command([cmake, "--build", "--preset", actual_preset])


def ensure_firmware_artifacts(preset: str) -> None:
    elf = artifact_path(preset, "elf")
    if not elf.is_file():
        raise RuntimeError(f"ELF not found for preset '{preset}': {elf}")

    objcopy = resolve_tool_path("ARM_NONE_EABI_OBJCOPY", ["arm-none-eabi-objcopy"], "GNU Arm Embedded objcopy")
    for extension in generated_artifact_extensions():
        fmt = "ihex" if extension == "hex" else "binary"
        run_command([objcopy, "-O", fmt, str(elf), str(artifact_path(preset, extension))])


def assert_expected_artifacts_exist(preset: str) -> None:
    for extension in expected_artifact_extensions():
        path = artifact_path(preset, extension)
        if not path.is_file():
            raise RuntimeError(f"Expected artifact missing for preset '{preset}': {path}")


def flash_config_value(name: str, default: Any = None) -> Any:
    flash = get_optional(load_config(), "flash", {})
    return get_optional(flash, name, default)


def openocd_scripts_root(openocd_path: str) -> Path | None:
    env_value = os.environ.get("OPENOCD_SCRIPTS", "").strip().strip('"')
    if env_value:
        path = Path(env_value).expanduser()
        if not path.exists():
            raise RuntimeError(f"OPENOCD_SCRIPTS does not exist: {path}")
        return path.resolve()

    derived = Path(openocd_path).resolve().parent / ".." / "share" / "openocd" / "scripts"
    derived = derived.resolve()
    return derived if derived.exists() else None


def resolve_openocd_config(openocd_path: str, env_var: str, relative_default: str | None, description: str) -> str:
    env_value = os.environ.get(env_var, "").strip().strip('"')
    if env_value:
        candidate = Path(env_value).expanduser()
        return str(candidate.resolve()) if candidate.exists() else env_value

    if relative_default:
        scripts_root = openocd_scripts_root(openocd_path)
        if scripts_root:
            candidate = (scripts_root / relative_default).resolve()
            if candidate.exists():
                return str(candidate)

    raise RuntimeError(f"Unable to locate {description}. Set {env_var} or OPENOCD_SCRIPTS.")


def clean_build_directories() -> None:
    root = repo_root().resolve()
    for preset in ("Debug", "Release"):
        directory = build_dir(preset).resolve()
        try:
            directory.relative_to(root)
        except ValueError as exc:
            raise RuntimeError(f"Refusing to delete path outside repository root: {directory}") from exc

        if directory.exists():
            shutil.rmtree(directory)
            print_success(f"[clean] Removed {directory}")
        else:
            print_warning(f"[clean] Nothing to remove for {preset}")


def size_summary(preset: str) -> dict[str, Any]:
    size_tool = resolve_tool_path("ARM_NONE_EABI_SIZE", ["arm-none-eabi-size"], "GNU Arm Embedded size")
    elf = artifact_path(preset, "elf")
    if not elf.is_file():
        raise RuntimeError(f"ELF not found for preset '{preset}': {elf}. Run the matching build first.")

    result = run_command([size_tool, str(elf)], capture_output=True)
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    if len(lines) < 2:
        raise RuntimeError("Unexpected arm-none-eabi-size output.")

    values = [item for item in lines[-1].split() if item]
    if len(values) < 5:
        raise RuntimeError("Unable to parse arm-none-eabi-size output.")

    text_size = int(values[0])
    data_size = int(values[1])
    bss_size = int(values[2])
    dec_size = int(values[3])
    hex_size = values[4]
    return {
        "lines": lines,
        "preset": preset,
        "elf": str(elf),
        "text": text_size,
        "data": data_size,
        "bss": bss_size,
        "dec": dec_size,
        "hex": hex_size,
        "flash": text_size + data_size,
        "ram": data_size + bss_size,
    }


def python_executable() -> str:
    return sys.executable
