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

## 新项目最小修改面

新项目接入时，优先只修改：

- `.local-ci/config.json`
- `.vscode/settings.json`
- `.vscode/launch.json`

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
