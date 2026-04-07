set shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

# Unified local entrypoint for build, flash, formatting, and local CI.

cmake := 'C:/Program Files/CMake/bin/cmake.exe'
clang_format := 'D:/DevEnv/llvm/bin/clang-format.exe'
cppcheck := 'D:/DevEnv/cppcheck/cppcheck.exe'
openocd := 'D:/DevEnv/openocd/bin/openocd.exe'
cmsis_dap_cfg := 'D:/DevEnv/openocd/share/openocd/scripts/interface/cmsis-dap.cfg'
stm32h7x_cfg := 'D:/DevEnv/openocd/share/openocd/scripts/target/stm32h7x.cfg'

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
    @& '{{openocd}}' -f '{{cmsis_dap_cfg}}' -f '{{stm32h7x_cfg}}' -c "program {{debug_elf}} verify reset exit"

deploy: build flash # Build and flash Debug

clean: # Remove build output
    @if (Test-Path '{{debug_build_dir}}') { Remove-Item -Recurse -Force '{{debug_build_dir}}' }
    @if (Test-Path '{{release_build_dir}}') { Remove-Item -Recurse -Force '{{release_build_dir}}' }

rebuild: clean build # Rebuild Debug from scratch

format: # Format user-owned application sources
    @$files = @()
    if (Test-Path 'App/Inc') { $files += Get-ChildItem -Path 'App/Inc' -Recurse -File | Where-Object { $_.Extension -eq '.h' } }
    if (Test-Path 'App/Src') { $files += Get-ChildItem -Path 'App/Src' -Recurse -File | Where-Object { $_.Extension -eq '.c' } }
    @foreach ($file in $files) { & '{{clang_format}}' -i $file.FullName }

check-static: # Run cppcheck on user-owned application sources only
    @$hasAppSources = (Test-Path 'App/Src') -and ((Get-ChildItem -Path 'App/Src' -Recurse -Filter *.c -File | Measure-Object).Count -gt 0)
    @if ($hasAppSources) { & '{{cppcheck}}' --project='{{debug_build_dir}}/compile_commands.json' --file-filter='App/*' --enable=warning,style,performance,portability --inline-suppr --force --quiet --std=c11 --suppress=missingIncludeSystem } else { Write-Host 'No user-owned App sources found. Skipping cppcheck.' }

check: build check-static # Build Debug and run static analysis
