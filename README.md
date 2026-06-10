# GCC_Cmake_ARM

`GCC_Cmake_ARM` 是面向 ARM Cortex-M 嵌入式工程的 GCC + CMake 项目模板仓库，目标是把 Keil/IAR 风格的单工程开发逐步迁移到可脚本化、可复现、可 CI 集成的现代嵌入式构建体系。

## 项目定位

| 项目 | 说明 |
| --- | --- |
| 类型 | ARM 嵌入式构建模板 |
| 目标平台 | STM32 / ARM Cortex-M 系列 MCU |
| 构建体系 | GCC Arm Embedded + CMake |
| 使用场景 | 本地构建、模板复用、CI 抽取、调试工具链验证 |
| 维护目标 | 工程可复制、构建可复现、配置可审查 |

## 核心能力

- 使用 CMake 组织嵌入式源码、启动文件、链接脚本和编译选项。
- 支持从传统 IDE 工程迁移到命令行构建流程。
- 为后续本地 CI、自动格式检查、静态检查预留入口。
- 适合作为 STM32、GD32、AT32、PY32 等 Cortex-M 项目的基础模板参考。

## 推荐目录结构

```text
GCC_Cmake_ARM/
├── CMakeLists.txt          # 顶层构建入口
├── cmake/                  # 工具链、芯片、编译选项配置
├── Core/                   # 启动代码、main、中断入口
├── Drivers/                # HAL / CMSIS / 外设驱动
├── BSP/                    # 板级资源适配
├── App/                    # 应用层示例
├── linker/                 # 链接脚本
└── scripts/                # 构建、清理、烧录、CI 辅助脚本
```

如果当前分支结构尚未完全符合上述布局，后续重构建议优先把“工具链配置、芯片配置、业务代码、链接脚本”分开，避免所有配置堆在顶层文件里。

## 快速开始

```powershell
cmake -S . -B build -G Ninja
cmake --build build
```

常见前置依赖：

- CMake
- Ninja 或 Make
- ARM GCC 工具链
- OpenOCD / pyOCD / J-Link 工具链，按目标板选择

## 工程配置原则

| 领域 | 标准 |
| --- | --- |
| 工具链 | 通过 CMake toolchain 文件统一配置 |
| 芯片参数 | CPU、FPU、ABI、链接脚本集中维护 |
| 编译选项 | Debug/Release 分离，禁止散落魔法参数 |
| 产物 | ELF、BIN、MAP 文件路径固定 |
| CI | 本地命令与 CI 命令保持一致 |

## 分支说明

| 分支 | 用途 |
| --- | --- |
| `master` | 通用 ARM GCC + CMake 模板主线 |
| `H743XIH_DAP` | STM32H743XIH6 + DAP 调试模板 |
| `template/stm32-local-ci-extract` | STM32 本地 CI 可复用模板 |
| `backup/hook-local-ci` | 本地 CI Hook 方案备份与参考 |

## 质量清单

- 新增芯片型号时必须同步 CPU/FPU/ABI/Linker Script。
- 新增源码目录时必须纳入 CMake target 管理。
- 构建命令需要能在干净环境复现。
- 编译警告应可解释，不能长期堆积。
- 模板分支应避免绑定个人绝对路径。

## 维护边界

该仓库的核心价值是“模板化”和“可复现”。具体业务项目应从模板派生，不建议在模板主线长期堆放业务逻辑。