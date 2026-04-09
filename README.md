# STM32 Local CI

这套仓库现在只保留一个文档入口，就是这份 `README.md`。

## 1. 先准备环境

团队统一做法是先运行：

```powershell
powershell -ExecutionPolicy Bypass -File D:\DevEnv\install_env.ps1
```

然后：

1. 关闭所有终端和 VS Code
2. 重新打开 VS Code 或终端
3. 确认下面这些命令能直接找到

```powershell
cmake --version
ninja --version
clangd --version
clang-format --version
cppcheck --version
arm-none-eabi-gcc --version
arm-none-eabi-gdb --version
openocd --version
```

再确认：

```powershell
echo $env:OPENOCD_SCRIPTS
```

## 2. 快速开始

仓库标准入口固定为：

```powershell
py -3 Scripts/ci/main.py <subcommand>
```

最常用的命令只有这些：

```powershell
py -3 Scripts/ci/main.py init
py -3 Scripts/ci/main.py build --preset Debug
py -3 Scripts/ci/main.py check
py -3 Scripts/ci/main.py check --full
py -3 Scripts/ci/main.py flash
```

VS Code 里对应的 Task 只保留：

- `ci: init`
- `ci: build`
- `ci: check`
- `ci: flash`

## 3. clangd / VS Code

当前仓库采用 `PATH` 模式，不再在仓库里写死 `D:\DevEnv\...` 绝对路径。

工作区里只保留最小 VS Code 配置：

- `.vscode/tasks.json`
- `.vscode/launch.json`
- `.vscode/settings.json`

其中：

- `clangd.path = clangd`
- `clangd` 通过 `build/Debug/compile_commands.json` 工作
- `clangd` 通过 `--query-driver=**/arm-none-eabi-*` 识别 ARM GCC
- 调试默认使用：
  - `arm-none-eabi-gdb`
  - `openocd`
  - `OPENOCD_SCRIPTS`

如果 `clangd` 没有头文件、跳转或补全，先不要改仓库路径，先确认：

1. `D:\DevEnv\install_env.ps1` 已跑过
2. VS Code 已重开
3. `clangd` 和 `arm-none-eabi-gcc` 都能在终端直接执行
4. `build/Debug/compile_commands.json` 已存在

## 4. G4 / H7 迁移时改什么

迁移本地 CI 时，不要重写 `Scripts/ci`。

通常只需要改项目层内容：

1. `.local-ci/config.json`
2. `.vscode/launch.json`
3. `.ioc`
4. CubeMX 生成层
5. 启动文件和链接脚本

常见芯片 target：

- H7: `target/stm32h7x.cfg`
- G4: `target/stm32g4x.cfg`

## 5. Lefthook pre-commit

当前默认只启用 `pre-commit`。

它会做：

- `git diff --cached --check`
- JSON 校验
- `Scripts/` 下 Python 语法检查
- 对 staged 的手写 C/C++ 文件执行 `clang-format`

不默认启用 `pre-push`。
