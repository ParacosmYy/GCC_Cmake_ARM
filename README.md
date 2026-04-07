# STM32H743XIH6 GCC + CMake 项目模板

基于 GCC ARM 工具链和 CMake 构建系统的 STM32H743XIH6 项目模板，支持 CMSIS-DAP 烧录器调试。

---

## 硬件信息

| 项目 | 规格 |
|------|------|
| **芯片型号** | STM32H743XIH6 |
| **封装** | TFBGA240 |
| **内核** | ARM Cortex-M7 (480MHz) |
| **Flash** | 2 MB |
| **RAM** | 1 MB (含 864KB AXI-SRAM + 128KB SRAM1/2/3 + 64KB ITCM/DTCM) |
| **烧录器** | CMSIS-DAP / DAPLink 兼容调试器 |
| **调试接口** | SWD (Serial Wire Debug) |

---

## 项目特性

- **RTOS**: FreeRTOS (CMSIS-RTOS v2 封装)
- **通信**: LPUART1 (低功耗串口)
- **DMA**: BDMA (备份 DMA) 支持收发双通道
- **构建系统**: CMake + Ninja
- **标准**: C11

---

## 工程结构

```
.
├── CMakeLists.txt              # 主 CMake 配置
├── CMakePresets.json           # CMake 预设配置
├── TEST_VSCODE_LPUART1_2.ioc   # STM32CubeMX 配置文件
├── startup_stm32h743xx.s       # 启动汇编文件
├── STM32H743XX_FLASH.ld        # 链接脚本
├── .gitignore                  # Git 忽略规则
├── cmake/                      # CMake 模块
│   ├── gcc-arm-none-eabi.cmake # GCC 工具链配置
│   ├── starm-clang.cmake       # Clang 工具链配置 (可选)
│   └── stm32cubemx/            # CubeMX 生成源配置
├── Core/                       # 用户代码
│   ├── Inc/                    # 头文件
│   └── Src/                    # 源文件
├── Drivers/                    # HAL 库和 CMSIS
│   ├── CMSIS/                  # ARM CMSIS 核心
│   └── STM32H7xx_HAL_Driver/   # STM32 HAL 库
└── Middlewares/                # 中间件
    └── Third_Party/FreeRTOS/   # FreeRTOS 内核
```

---

## 快速开始

### 前置要求

1. 安装 `GCC_Toolchain` 分支的工具链：
   ```bash
   git clone -b GCC_Toolchain https://github.com/ParacosmYy/GCC-Cmake-ARM-.git D:\DevEnv
   cd D:\DevEnv
   .\install_env.ps1
   ```
2. 重启终端使环境变量生效

### 构建项目

```bash
cd <项目目录>

# 配置 (Debug 模式)
cmake --preset Debug

# 构建
cmake --build build/Debug

# 生成 hex/bin (可选)
arm-none-eabi-objcopy -O ihex build/Debug/TEST_VSCODE_LPUART1_2.elf build/Debug/TEST_VSCODE_LPUART1_2.hex
```

### 烧录程序

```bash
# 使用 OpenOCD + CMSIS-DAP 烧录
openocd -f D:\DevEnv\stm32h7_cmsis_dap.cfg -c "program build/Debug/TEST_VSCODE_LPUART1_2.elf verify reset exit"

# 或使用 hex 文件
openocd -f D:\DevEnv\stm32h7_cmsis_dap.cfg -c "program build/Debug/TEST_VSCODE_LPUART1_2.hex verify reset exit"
```

### 调试

```bash
# 启动 OpenOCD 服务器
openocd -f D:\DevEnv\stm32h7_cmsis_dap.cfg

# 在另一个终端启动 GDB
arm-none-eabi-gdb build/Debug/TEST_VSCODE_LPUART1_2.elf
(gdb) target remote localhost:3333
(gdb) monitor reset halt
(gdb) load
(gdb) continue
```

---

## 切换芯片指南

如需将此模板适配到其他 STM32H7 芯片或不同系列：

### 1. 替换启动文件

```bash
# 从 CMSIS 设备支持包获取对应芯片的 startup_xxx.s
# 例如 STM32H750: startup_stm32h750xx.s
```

### 2. 替换链接脚本

```bash
# 从 CMSIS 获取对应芯片的链接脚本
# 修改 FLASH/RAM 起始地址和大小以匹配目标芯片
```

### 3. 修改 CMake 工具链配置

编辑 `cmake/gcc-arm-none-eabi.cmake`：

```cmake
# 修改芯片型号定义
set(MCU_FLAGS "-mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard")
add_definitions(-DSTM32H743xx)  # 改为对应型号，如 STM32H750xx
```

### 4. 更新 CubeMX 配置

1. 打开 `.ioc` 文件
2. 选择新芯片型号
3. 重新生成代码

---

## 切换烧录器指南

根据使用的调试器选择对应配置文件：

| 烧录器类型 | 配置文件 | 适用场景 |
|-----------|----------|---------|
| CMSIS-DAP | `stm32h7_cmsis_dap.cfg` | DAPLink、HS-Link、WCH-Link 等 |
| J-Link | `stm32h7_jlink.cfg` | Segger J-Link / J-Link OB |
| ST-Link | `stm32h7_stlink.cfg` | ST-Link V2/V3 |

在 `GCC_Toolchain` 分支中获取对应配置文件。

---

## 引脚配置

| 功能 | 引脚 | 模式 |
|------|------|------|
| LPUART1_TX | PA9 | 复用推挽 |
| LPUART1_RX | PA10 | 复用输入 |

---

## 参考资源

- [STM32H743 Reference Manual (RM0433)](https://www.st.com/resource/en/reference_manual/rm0433-stm32h742-stm32h743753-and-stm32h750-value-line-advanced-armbased-32bit-mcus-stmicroelectronics.pdf)
- [STM32H743 Datasheet](https://www.st.com/resource/en/datasheet/stm32h743xi.pdf)
- [FreeRTOS Documentation](https://www.freertos.org/Documentation/RTOS_book.html)

---

## 许可证

MIT License
