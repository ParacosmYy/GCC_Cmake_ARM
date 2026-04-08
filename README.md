# STM32 本地 CI

本仓库采用 Python 优先的本地 CI 设计，目标是让同一套流程同时适用于：

- Windows 本地开发机
- Linux 云端 CI Runner
- 后续固件产物流程，例如版本注入、CRC、签名、OTA 打包

## 企业标准入口

本仓库的企业标准入口是：

```bash
python3 scripts/ci/main.py <subcommand>
```

在 Windows 上推荐使用：

```powershell
py -3 scripts/ci/main.py <subcommand>
```

例如：

```powershell
py -3 scripts/ci/main.py init
py -3 scripts/ci/main.py build --preset Debug
py -3 scripts/ci/main.py check
```

这条入口是整个本地 CI 和云端 CI 的统一标准接口，适用于：

- 开发者终端
- 云端 CI 流水线
- 后续 Jenkins、GitLab CI、GitHub Actions、Azure DevOps

## `just` 和 VS Code Task 的关系

这里需要明确三层关系：

1. 标准入口是 `scripts/ci/main.py`
2. `just` 是开发者友好入口
3. VS Code Task 是 IDE 便利层

也就是说：

- 企业标准不是 VS Code Task
- 企业标准也不一定必须是 `just`
- 本仓库当前的主标准是 Python CLI
- `just` 只是对 Python CLI 的简化封装
- VS Code Task 只是为了少敲命令

当前仓库里：

- `just build` 最终会调用 `scripts/ci/main.py build`
- `just check` 最终会调用 `scripts/ci/main.py check`
- VS Code Task 当前也是直接调用 `scripts/ci/main.py`

所以你现在的 VS Code Task 和 `just` 没有直接调用关系，它们是两个并列的便利层，底层都指向同一个 Python 主入口。

## 目录分层

- `scripts/ci/main.py`：企业标准入口
- `scripts/ci/*.py`：可复用 CI 实现
- `scripts/hooks/*.py`：Git Hook 包装层
- `Justfile`：开发者友好命令层
- `lefthook.yml`：Git 生命周期接入层
- `.local-ci/config.json`：项目级配置
- `.vscode/*`：IDE 便利层，不承载 CI 逻辑

## 快速开始

企业标准入口：

```powershell
py -3 scripts/ci/main.py init
py -3 scripts/ci/main.py build --preset Debug
py -3 scripts/ci/main.py check
```

开发者快捷入口：

```powershell
just init
just build
just check
```

## 支持的子命令

企业标准子命令：

```text
init
configure [--preset All|Debug|Release]
build [--preset Debug|Release]
format [--check]
lint
size [--preset Debug|Release]
check
flash [--preset Debug|Release]
clean
```

对应的开发者快捷命令：

```powershell
just init
just configure
just build
just rebuild
just build-release
just format
just format-check
just lint
just size
just check
just flash
just clean
```

## 环境要求

必需工具：

- `python3`，Windows 下推荐 `py -3`
- `just`
- `cmake`
- `ninja`
- `arm-none-eabi-gcc`
- `arm-none-eabi-objcopy`
- `arm-none-eabi-size`
- `clang-format`
- `cppcheck`
- `git`
- `lefthook`
- `openocd`，仅在需要烧录时必需

如果工具不在 `PATH`，可以通过这些环境变量覆盖：

- `CMAKE`
- `NINJA`
- `CLANG_FORMAT`
- `CPPCHECK`
- `OPENOCD`
- `LEFTHOOK`
- `ARM_NONE_EABI_GCC`
- `ARM_NONE_EABI_OBJCOPY`
- `ARM_NONE_EABI_SIZE`

## 项目配置

项目级差异集中放在：

- [.local-ci/config.json](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/.local-ci/config.json)

这个文件负责描述：

- 项目名
- Debug / Release preset 映射
- 固件产物基名
- 生成哪些附加产物
- format / lint 检查范围
- OpenOCD 默认目标配置

配置 schema 在这里：

- [.local-ci/config.schema.json](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/.local-ci/config.schema.json)

STM32G4 示例配置在这里：

- [.local-ci/examples/stm32g4-config.json](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/.local-ci/examples/stm32g4-config.json)

## VS Code 集成

VS Code 只是 IDE 便利层，不是企业标准入口。

考虑到你们当前是 GCC 初始开发团队，仓库保留了一组精简的核心 Task，方便团队成员直接在 IDE 里完成日常动作。

当前保留的核心 Task：

- `ci: init`
- `ci: build`
- `ci: build-release`
- `ci: check`
- `ci: flash`
- `ci: clean`

这些 Task 定义在：

- [.vscode/tasks.json](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/.vscode/tasks.json)

Windows 下 Task 用 `py -3`，Linux / macOS 下用 `python3`。  
所有 Task 都直接调用 `scripts/ci/main.py`。

`format`、`lint`、`size`、`configure` 这些动作仍然保留在企业标准入口和 `just` 里，但不再全部暴露到 VS Code Task 列表中，避免 IDE 菜单过长。

调试配置在：

- [.vscode/launch.json](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/.vscode/launch.json)

工具路径和调试参数覆盖在：

- [.vscode/settings.json](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/.vscode/settings.json)

推荐扩展在：

- [.vscode/extensions.json](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/.vscode/extensions.json)

## 构建产物

每个 preset 期望产出：

- `.elf`
- `.map`
- `.bin`
- `.hex`

其中：

- `.elf` 和 `.map` 由项目构建产生
- `.bin` 和 `.hex` 由 Python CI 层在构建后统一生成

## 跨芯片复用

如果后续是 G4、F4 或其他 STM32 项目要复用这套本地 CI，通常只需要：

1. 复用 `scripts/ci/*.py`
2. 复用 `scripts/hooks/*.py`
3. 复用 `Justfile`
4. 复用 `lefthook.yml`
5. 新建自己的 `.local-ci/config.json`

通常只需要调整这些项目级字段：

- `project.name`
- `build.presets`
- `artifacts.base_name`
- `quality.include`
- `quality.exclude`
- `flash.target_cfg`

正常情况下，不应该因为换芯片就修改 Python CI 主体逻辑。

## 接入说明

详见：

- [docs/local-ci-adoption.md](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/docs/local-ci-adoption.md)

## Windows 说明

有些 Windows 环境里，`python` 会指向 Microsoft Store 占位程序，而不是真实解释器。

本仓库当前通过以下方式规避这个问题：

- VS Code Task 使用 `py -3`
- Windows Git Hook 使用 `py -3`
- 文档里的 Windows 标准命令统一使用 `py -3 scripts/ci/main.py ...`
