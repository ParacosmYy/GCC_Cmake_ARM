set shell := ["sh", "-cu"]
set windows-shell := ["cmd.exe", "/Q", "/C"]

python_cmd := if os_family() == "windows" { "py -3" } else { "python3" }

init: # Validate local tools and install git hooks
    @{{python_cmd}} scripts/ci/main.py init

configure: # Configure Debug and Release build directories
    @{{python_cmd}} scripts/ci/main.py configure

build: # Build Debug
    @{{python_cmd}} scripts/ci/main.py build --preset Debug

rebuild: clean build # Rebuild Debug from scratch

build-release: # Build Release
    @{{python_cmd}} scripts/ci/main.py build --preset Release

format: # Format hand-maintained sources
    @{{python_cmd}} scripts/ci/main.py format

format-check: # Verify formatting without changing files
    @{{python_cmd}} scripts/ci/main.py format --check

lint: # Run static analysis on hand-maintained sources
    @{{python_cmd}} scripts/ci/main.py lint

size: # Print firmware size summary for Debug
    @{{python_cmd}} scripts/ci/main.py size --preset Debug

check: # Run the full local quality gate
    @{{python_cmd}} scripts/ci/main.py check

flash: # Flash the configured firmware preset
    @{{python_cmd}} scripts/ci/main.py flash

clean: # Remove build output
    @{{python_cmd}} scripts/ci/main.py clean
