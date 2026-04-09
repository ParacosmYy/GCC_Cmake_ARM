# STM32 Local CI Template

这个分支就是团队长期维护的本地 CI 模板分支。
它只提供模板层，不包含任何 STM32 工程产物。

模板层包含：

- `Scripts/ci/`
- `Scripts/hooks/`
- `.vscode/tasks.json`
- `.vscode/launch.json`
- `.vscode/settings.json`
- `.local-ci/config.json`
- `.local-ci/template-version.json`
- `.clangd`
- `.clang-format`
- `lefthook.yml`
- `install-local-ci.ps1`

目标项目需要自己提供项目层内容，例如：

- `CMakeLists.txt`
- `CMakePresets.json`
- `.ioc`
- `Core/`
- `Drivers/`
- `Middlewares/`
- 启动文件
- 链接脚本
- CubeMX 生成层和业务代码

## 1. 先准备环境

先运行统一环境脚本：

```powershell
powershell -ExecutionPolicy Bypass -File D:\DevEnv\install_env.ps1
```

然后重开终端或 VS Code，并确认下面命令都能直接执行：

```powershell
cmake --version
ninja --version
clangd --version
clang-format --version
cppcheck --version
arm-none-eabi-gcc --version
arm-none-eabi-gdb --version
openocd --version
echo $env:OPENOCD_SCRIPTS
```

## 2. 第一次接入现有项目

在这个模板仓库里执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-local-ci.ps1 -TargetProject <目标项目路径>
```

常用可选参数：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-local-ci.ps1 `
  -TargetProject D:\Workplace\MyProject `
  -ProjectName MyProject `
  -ArtifactBaseName MyProject `
  -OpenOcdInterfaceCfg interface/cmsis-dap.cfg `
  -OpenOcdTargetCfg target/stm32g4x.cfg
```

如果目标目录还没生成出明显的 STM32 工程骨架，可以显式放行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-local-ci.ps1 `
  -TargetProject <目标项目路径> `
  -Force
```

默认行为：

- 强覆盖模板脚本层，并自动备份同名旧文件
- `.vscode/*.json` 和 `.local-ci/config.json` 若已存在，会先备份再覆盖
- 不复制、不覆盖任何项目层文件

## 3. 已接入项目如何升级模板层

已接入项目升级时，重新运行同一个导入脚本即可：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-local-ci.ps1 -TargetProject <目标项目路径>
```

升级时脚本会：

- 检测目标项目已有的 `.local-ci/config.json`
- 打印当前项目模板版本和即将导入的模板版本
- 更新模板层文件
- 备份后覆盖 `.vscode/*.json` 和 `.local-ci/config.json`
- 不碰 `.ioc`、`Core/`、`Drivers/`、`Middlewares/`、链接脚本、启动文件等项目层内容

项目当前接入的是哪个模板版本，看这里：

```text
.local-ci/template-version.json
```

## 4. 接入后怎么验证

进入目标项目后执行：

```powershell
py -3 Scripts/ci/main.py init
py -3 Scripts/ci/main.py build --preset Debug
py -3 Scripts/ci/main.py check
```

VS Code 常用任务入口：

- `ci: init`
- `ci: build`
- `ci: check`
- `ci: flash`

`Lefthook` 默认只启用 `pre-commit`，会做这些轻检查：

- `git diff --cached --check`
- JSON 校验
- `Scripts/` 下 Python 语法检查
- 对 staged 的手写 C/C++ 文件执行 `clang-format`

## 5. 遇到问题先看哪里

优先检查这几项：

1. `cmake`、`clangd`、`py` 是否已经在 `PATH`
2. `OPENOCD_SCRIPTS` 是否存在
3. 目标项目是否已经有 `CMakeLists.txt` 和 `CMakePresets.json`
4. `build/Debug/compile_commands.json` 是否已经生成
5. `.local-ci/config.json` 和 `.vscode/launch.json` 是否已经按目标芯片改好

如果目标项目不是 H7，通常至少要同步调整：

- `.local-ci/config.json`
- `.vscode/launch.json`
- `OpenOCD target cfg`
- 项目自己的 `.ioc` 和 CubeMX 工程层
