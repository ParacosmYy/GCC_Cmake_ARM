# 本地 CI 接入指南

## 目标

在多个 STM32 项目之间复用同一套本地 CI 基座，同时保持 CubeMX 生成框架不被破坏。

## 标准入口

标准入口统一为：

```bash
python3 Scripts/ci/main.py <subcommand>
```

Windows 对应：

```powershell
py -3 Scripts/ci/main.py <subcommand>
```

推荐命令：

- 本地快检：`py -3 Scripts/ci/main.py check`
- 完整检查：`py -3 Scripts/ci/main.py check --mode full`

## 目录约定

CubeMX 生成内容：

- `Core/`
- `Drivers/`
- `Middlewares/`

手写代码与自动化脚本：

- `App/`
- `Bsp/`
- `Service/`
- `Config/`
- `Board/`
- `Scripts/`

## 通用文件

下面这些通常可以直接在新项目中复用：

- `Scripts/ci/*.py`
- `Scripts/hooks/*.py`
- `Justfile`
- `lefthook.yml`
- `.local-ci/config.schema.json`
- `.vscode/tasks.json`

## 项目级文件

下面这些通常需要按项目调整：

- `.local-ci/config.json`
- `.vscode/settings.json`
- `.vscode/launch.json`
- `README.md`

## 团队统一原则

如果团队同时维护 H7、G4、F4 等多个 STM32 项目，建议统一的是“本地 CI 基座”，而不是强行让所有项目共用一份芯片配置。

团队层面尽量保持不变：

- 标准入口统一为 `py -3 Scripts/ci/main.py <subcommand>`
- VS Code Task 名称统一为 `ci: init`、`ci: build`、`ci: check`、`ci: flash`
- 工具目录统一为 `D:\DevEnv`
- Hook 管理统一使用 `lefthook`
- 目录分层统一为 CubeMX 生成层加用户自维护层

芯片或项目层面按实际调整：

- `.ioc`
- `Core/`
- `Drivers/`
- `Middlewares/`
- 启动文件
- 链接脚本
- `cmake/stm32cubemx/CMakeLists.txt`
- 项目名和产物名
- OpenOCD target 配置

## 关于 `D:\DevEnv`

`D:\DevEnv` 是团队当前推荐的默认工具目录，不是本地 CI 的硬性前提。

这套本地 CI 本质上依赖的是：

- 能找到 `cmake`、`ninja`、`arm-none-eabi-gcc`、`clang-format`、`cppcheck`、`lefthook`
- 需要烧录时能找到 `openocd`
- VS Code Task 能把这些工具路径传给 `Scripts/ci/main.py`

如果开发机没有 D 盘，仍然可以接入，只是需要把工具路径改到实际安装位置。

常见做法有两种：

- 团队统一约定另一个目录，例如 `C:\DevEnv`
- 把工具加入 `PATH`，或通过环境变量传入

当前代码并没有把 D 盘写死在 CI 逻辑里；真正的 CI 逻辑会优先读取环境变量，其次从 `PATH` 查找工具。

需要注意的是：

- 当前 `.vscode/settings.json` 默认写的是 `D:/DevEnv/...`
- 所以如果直接使用仓库默认的 VS Code 配置，没有 D 盘时会先在 IDE 层失败
- 这属于“默认配置需要调整”，不等于“本地 CI 无法工作”

## 新项目最小修改面

新项目接入时，优先只修改：

- `.local-ci/config.json`
- `.vscode/settings.json`
- `.vscode/launch.json`

补充说明：

- 如果只是同一模板下派生一个新项目，通常先改上面这三处即可。
- 如果是从 H7 切到 G4 这种“换芯片族”的新工程，还需要同步替换对应的 CubeMX 生成层和启动文件，而不是只改本地 CI 配置。

## G4 项目接入建议

如果同事要新开一个 STM32G4 项目，推荐按下面顺序接入本地 CI。

1. 先复制团队通用基座。
2. 保留 `Scripts/ci/*.py`、`Scripts/hooks/*.py`、`Justfile`、`lefthook.yml`、`.vscode/tasks.json`、`.local-ci/config.schema.json` 不变。
3. 用 CubeMX 生成 G4 项目的 `.ioc`、`Core/`、`Drivers/`、`Middlewares/`、启动文件、链接脚本，并更新 `cmake/stm32cubemx/CMakeLists.txt`。
4. 修改 `.local-ci/config.json` 里的 `project.name`、`artifacts.base_name`、`flash.target_cfg` 等项目字段。
5. 修改 `.vscode/settings.json` 里的 `localCi.debug.elfPath` 和 `localCi.debug.openocdTargetCfg`。
6. 如调试方式没变，`.vscode/launch.json` 通常可以不动；如果下载器、RTOS 或启动任务变了，再按项目调整。
7. 进入仓库后执行 `py -3 Scripts/ci/main.py init`、`py -3 Scripts/ci/main.py build --preset Debug`、`py -3 Scripts/ci/main.py check` 验证基座是否接通。

对 G4 项目来说，通常不需要改的东西：

- `Scripts/ci/main.py`
- `Scripts/ci/check.py`
- `Scripts/ci/build.py`
- `Scripts/ci/lint.py`
- `Justfile`
- `.vscode/tasks.json`

对 G4 项目来说，通常需要改的东西：

- `.local-ci/config.json`
- `.vscode/settings.json`
- `.vscode/launch.json`
- `.ioc`
- `cmake/stm32cubemx/CMakeLists.txt`
- 启动文件和链接脚本

当前团队环境下，G4 的 OpenOCD target 配置可使用：

```text
target/stm32g4x.cfg
```

这意味着同事换到 G4 时，本地 CI 的思路不是“重写一套 CI”，而是“复用同一套 CI 基座，只替换芯片相关配置”。

## 当前团队通用基座是什么

如果按当前仓库来定义，“团队通用基座”指的是这批可跨项目复用的内容：

- `Scripts/ci/*.py`
- `Scripts/hooks/*.py`
- `Justfile`
- `lefthook.yml`
- `.vscode/tasks.json`
- `.local-ci/config.schema.json`
- 文档约定，例如 `docs/local-ci-adoption.md`

通常还会一起带上这些“半通用”文件作为模板起点：

- `.local-ci/config.json`
- `.vscode/settings.json`
- `.vscode/launch.json`
- `CMakePresets.json`

需要按芯片和项目替换的，不属于通用基座本体：

- `.ioc`
- `Core/`
- `Drivers/`
- `Middlewares/`
- 启动文件
- 链接脚本
- `cmake/stm32cubemx/CMakeLists.txt`

当前这套基座已经在本仓库里成形了，但还没有被单独打包成一个独立模板仓库或压缩包。

换句话说：

- 现在的“基座”是已经存在的
- 但它目前是“散布在当前仓库中的可复用部分”
- 还不是一个单独发布的 `stm32-local-ci-template` 仓库

## `.local-ci/config.json` 主要修改点

按项目实际情况修改：

- `project.name`
- `build.presets`
- `artifacts.base_name`
- `quality.format.include`
- `quality.format.exclude`
- `quality.lint.include`
- `quality.lint.exclude`
- `flash.interface_cfg`
- `flash.target_cfg`

## `.vscode/settings.json` 主要修改点

按团队环境或项目差异修改：

- `localCi.tools.*`
- `localCi.debug.elfPath`
- `localCi.debug.openocdInterfaceCfg`
- `localCi.debug.openocdTargetCfg`

## `.vscode/launch.json` 主要修改点

通常只在调试策略变化时修改：

- 调试器类型
- `preLaunchTask`
- RTOS 配置

## 本地与推送策略

- 本地 `check` 默认使用快速模式
- 快速模式优先检查变更过的手写 C/C++ 文件
- 如果当前变更不涉及手写 C/C++，本地 `cppcheck` 会跳过
- `pre-push` 仍执行 `check --mode full`

## IDE 集成

VS Code Task 只是便利层，不是标准入口。当前保留：

- `ci: init`
- `ci: build`
- `ci: build-release`
- `ci: check`
- `ci: check-full`
- `ci: flash`
- `ci: clean`

说明：

- 所有 Task 都调用 `Scripts/ci/main.py`
- 构建与检查任务已配置 `problemMatcher`
- 报错会进入 `Problems` 面板，便于定位文件与行号
