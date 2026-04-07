set shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-Command"]

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

build: # 编译 Debug
    @& '{{cmake}}' --preset {{debug_preset}}

build-release: # 编译 Release
    @& '{{cmake}}' --preset {{release_preset}}

flash: # 烧录 Debug 固件
    @& '{{openocd}}' -f '{{cmsis_dap_cfg}}' -f '{{stm32h7x_cfg}}' -c "program {{debug_elf}} verify reset exit"

deploy: build flash # 编译并烧录 Debug

clean: # 清理构建产物
    @if (Test-Path '{{debug_build_dir}}') { Remove-Item -Recurse -Force '{{debug_build_dir}}' }
    @if (Test-Path '{{release_build_dir}}') { Remove-Item -Recurse -Force '{{release_build_dir}}' }

rebuild: clean build # 完整重建 Debug

format: # 格式化 C/C++ 源码
    @$files = Get-ChildItem -Path 'Core/Inc','Core/Src' -Recurse -File | Where-Object { $_.Extension -in '.c', '.h' }
    @foreach ($file in $files) { & '{{clang_format}}' -i $file.FullName }

check: build # 格式检查 + 静态分析
    @& '{{cppcheck}}' --project='{{debug_build_dir}}/compile_commands.json' --file-filter='Core/*' --enable=warning,style,performance,portability --inline-suppr --force --quiet --std=c11 --suppress=missingIncludeSystem
