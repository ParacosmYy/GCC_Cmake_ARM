# STM32H743XIH6 GCC + CMake DAP Template

`H743XIH_DAP` 是面向 STM32H743XIH6 的 GCC + CMake 工程模板分支，重点验证 Cortex-M7 芯片在命令行构建、链接脚本、CMSIS-DAP 调试和本地烧录流程中的完整闭环。

## 项目定位

| 项目 | 说明 |
| --- | --- |
| 类型 | STM32H743XIH6 工程模板 |
| 内核 | ARM Cortex-M7 |
| 构建体系 | GCC Arm Embedded + CMake |
| 调试方式 | CMSIS-DAP / OpenOCD 方向 |
| 分支职责 | H743 芯片级构建、链接、下载、调试基线 |

## H743 关键关注点

STM32H7 系列相对 F1/F4 工程更容易踩坑，README 中建议长期维护以下信息：

- CPU/FPU/ABI 编译参数是否匹配 Cortex-M7。
- Linker Script 是否正确描述 Flash、RAM、DTCM、AXI SRAM 等区域。
- Cache、MPU、DMA Buffer 是否存在一致性问题。
- 启动文件、SystemInit、时钟树配置是否与芯片型号一致。
- OpenOCD 或 DAP 调试配置是否可从干净环境复现。

## 推荐目录结构

```text
H743XIH_DAP/
├── CMakeLists.txt
├── cmake/
│   ├── arm-none-eabi.cmake
│   └── stm32h743.cmake
├── Core/
│   ├── Src/
│   └── Inc/
├── Drivers/
│   ├── CMSIS/
│   └── STM32H7xx_HAL_Driver/
├── linker/
│   └── STM32H743XIHx_FLASH.ld
├── openocd/
│   └── cmsis-dap.cfg
└── scripts/
```

## 快速开始

```powershell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

建议构建产物：

| 产物 | 用途 |
| --- | --- |
| `.elf` | 调试和符号分析 |
| `.bin` | 烧录或升级输入 |
| `.hex` | 兼容传统烧录工具 |
| `.map` | 内存占用和链接分析 |

## 调试流程

```text
安装 ARM GCC / CMake / Ninja
    -> 配置 OpenOCD 或 DAP 工具
    -> CMake 生成构建目录
    -> 编译 ELF/BIN
    -> 下载到目标板
    -> 断点验证 Reset_Handler -> main
```

## 质量标准

| 检查项 | 要求 |
| --- | --- |
| 编译参数 | `-mcpu=cortex-m7`、FPU、float ABI 明确 |
| 链接脚本 | Flash/RAM 区域与芯片手册一致 |
| 启动文件 | 向量表、中断名、SystemInit 匹配 H743 |
| 调试配置 | DAP/OpenOCD 配置可复用，不绑定个人路径 |
| 内存分析 | MAP 文件可用于定位段分布和栈堆配置 |

## 维护边界

该分支用于沉淀 H743XIH6 的工程模板能力，不建议长期承载具体业务应用。业务项目应从此分支抽取模板后独立维护，模板分支只保留芯片、构建、下载、调试所需的最小闭环。