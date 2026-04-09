# 新人入职环境搭建指南

## 适用范围

适用于本项目 Windows 本地开发环境，工具链组合为：

- GCC
- CMake
- Python
- just
- OpenOCD
- VS Code

## 团队标准工具目录

团队当前统一工具目录为：

```text
D:\DevEnv
```

推荐结构：

```text
D:\DevEnv
  cmake
  ninja
  llvm
  cppcheck
  lefthook
  openocd
  GNU-tools-for-STM32
  just
  git
```

## 必装工具

- `D:\DevEnv\cmake\bin\cmake.exe`
- `D:\DevEnv\ninja\ninja.exe`
- `D:\DevEnv\llvm\bin\clang-format.exe`
- `D:\DevEnv\cppcheck\cppcheck.exe`
- `D:\DevEnv\lefthook\lefthook.exe`
- `D:\DevEnv\openocd\bin\openocd.exe`
- `D:\DevEnv\GNU-tools-for-STM32\bin\arm-none-eabi-gcc.exe`
- `D:\DevEnv\GNU-tools-for-STM32\bin\arm-none-eabi-objcopy.exe`
- `D:\DevEnv\GNU-tools-for-STM32\bin\arm-none-eabi-size.exe`
- `D:\DevEnv\GNU-tools-for-STM32\bin\arm-none-eabi-gdb.exe`
- `py -3`
- `just`

## 第一次拉取项目后的操作

1. 打开 VS Code。
2. 确认 `.vscode/settings.json` 中的工具路径与团队标准一致。
3. 运行 `Run Task -> ci: init`。
4. 运行 `Run Task -> ci: build`。
5. 运行 `Run Task -> ci: check`。
6. 如需接板调试，运行 `Run Task -> ci: flash` 或直接启动 `Debug STM32 (OpenOCD)`。

## 哪些文件是通用的

新人一般不需要修改：

- `Scripts/ci/*.py`
- `Scripts/hooks/*.py`
- `Justfile`
- `lefthook.yml`
- `.vscode/tasks.json`
- `.local-ci/config.schema.json`

## 哪些文件可能需要项目负责人修改

- `.local-ci/config.json`
- `.vscode/settings.json`
- `.vscode/launch.json`
- `README.md`

## 这些文件具体改什么

### `.local-ci/config.json`

按项目修改：

- `project.name`
- `build.presets`
- `artifacts.base_name`
- `quality.format.include`
- `quality.format.exclude`
- `quality.lint.include`
- `quality.lint.exclude`
- `flash.interface_cfg`
- `flash.target_cfg`

### `.vscode/settings.json`

按团队环境或项目差异修改：

- `localCi.tools.*`
- `localCi.debug.elfPath`
- `localCi.debug.openocdInterfaceCfg`
- `localCi.debug.openocdTargetCfg`

### `.vscode/launch.json`

通常只在调试策略变化时修改：

- 调试器类型
- `preLaunchTask`
- RTOS 配置

## 代码该放哪里

除 CubeMX 生成内容外，手写代码统一放在：

- `App/`
- `Bsp/`
- `Service/`
- `Config/`
- `Board/`
- `Scripts/`

不要把长期维护代码直接堆到：

- `Drivers/`
- `Middlewares/`

`Core/` 当前只保留过渡期入口修改。

## 规范检查会拦截什么

- `App/`、`Bsp/`、`Service/`、`Config/`、`Board/` 下的手写 C/C++ 代码
- `Scripts/` 下的 Python 语法
- 过渡期保留 `Core/Inc/main.h`
- 过渡期保留 `Core/Src/main.c`

## 日常推荐用法

- 快速自检：`Run Task -> ci: check`
- 完整自检：`Run Task -> ci: check-full`
- 命令行标准入口：`py -3 Scripts/ci/main.py check`

说明：

- `ci: check` 适合日常开发
- `ci: check-full` 适合推送前完整确认
- 构建和检查任务的关键报错会进入 VS Code `Problems` 面板
