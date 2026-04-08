set shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

# Unified local entrypoint for build, flash, formatting, and local CI.

cmake := 'C:/Program Files/CMake/bin/cmake.exe'
clang_format := 'D:/DevEnv/llvm/bin/clang-format.exe'
cppcheck := 'D:/DevEnv/cppcheck/cppcheck.exe'
openocd := 'D:/DevEnv/openocd/bin/openocd.exe'
cmsis_dap_cfg := 'D:/DevEnv/cfg/stm32h7_cmsis_dap.cfg'
lefthook := 'D:/DevEnv/lefthook/lefthook.exe'

debug_preset := 'Debug'
release_preset := 'Release'
debug_build_dir := 'build/Debug'
release_build_dir := 'build/Release'
debug_elf := 'build/Debug/TEST_VSCODE_LPUART1_2.elf'

build: # Build Debug
    @& '{{cmake}}' --preset {{debug_preset}}
    @& '{{cmake}}' --build --preset {{debug_preset}}

build-release: # Build Release
    @& '{{cmake}}' --preset {{release_preset}}
    @& '{{cmake}}' --build --preset {{release_preset}}

flash: # Flash Debug firmware
    @& '{{openocd}}' -f '{{cmsis_dap_cfg}}' -c "program {{debug_elf}} verify reset exit"

deploy: build flash # Build and flash Debug

clean: # Remove build output
    @if (Test-Path '{{debug_build_dir}}') { Remove-Item -Recurse -Force '{{debug_build_dir}}' }
    @if (Test-Path '{{release_build_dir}}') { Remove-Item -Recurse -Force '{{release_build_dir}}' }

rebuild: clean build # Rebuild Debug from scratch

init-hooks: # Install repository hooks for this checkout
    @if ((@(& git status --porcelain)).Count -gt 0) { throw 'Working tree must be clean before installing hooks.' }
    @$lefthookExe = if ($env:LEFTHOOK -and (Test-Path $env:LEFTHOOK)) { $env:LEFTHOOK } else { '{{lefthook}}' }
    @if (-not (Test-Path $lefthookExe)) { throw "lefthook executable not found: $lefthookExe" }
    @& $lefthookExe install

format: # Format hand-maintained Core sources only
    @& '{{clang_format}}' -i 'Core/Inc/main.h' 'Core/Src/main.c'

check-static: # Run cppcheck on hand-maintained Core sources only
    @if ((Test-Path 'Core/Src/main.c')) { & '{{cppcheck}}' --project='{{debug_build_dir}}/compile_commands.json' --file-filter='Core/Src/main.c' --enable=warning,style,performance,portability --inline-suppr --force --quiet --std=c11 --suppress=missingIncludeSystem --suppress=constParameterPointer --suppress='*:*Drivers/*' --suppress='*:*Middlewares/*' --error-exitcode=1 } else { Write-Host 'No hand-maintained Core sources found. Skipping cppcheck.' }

check: build check-static # Build Debug and run static analysis
