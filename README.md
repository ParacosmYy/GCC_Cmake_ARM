# STM32H743XIH6 GCC + CMake 项目模板

基于 GCC ARM 工具链和 CMake 构建系统的 STM32H743XIH6 项目模板，支持 CMSIS-DAP 烧录器调试。

> 团队统一入口建议直接使用 `Justfile` 和 VS Code 任务；PowerShell 里如果已配置 profile，也可以直接执行 `just`。
---

## 硬件信息

| 项目         | 规格                                                        |
| ------------ | ----------------------------------------------------------- |
| **芯片型号** | STM32H743XIH6                                               |
| **封装**     | TFBGA240                                                    |
| **内核**     | ARM Cortex-M7 (480MHz)                                      |
| **Flash**    | 2 MB                                                        |
| **RAM**      | 1 MB (含 864KB AXI-SRAM + 128KB SRAM1/2/3 + 64KB ITCM/DTCM) |
| **烧录器**   | CMSIS-DAP / DAPLink 兼容调试器                              |
| **调试接口** | SWD (Serial Wire Debug)                                     |

---

## 项目特性

- **RTOS**: FreeRTOS (CMSIS-RTOS v2 封装)
- **通信**: LPUART1 (低功耗串口)
- **DMA**: BDMA (备份 DMA) 支持收发双通道
- **构建系统**: CMake + Ninja + Just
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
2. 安装 `Just`、`OpenOCD` 和 `clang-format` / `cppcheck`
3. 重启终端使环境变量生效

### 统一工作流

```bash
cd <项目目录>

# 如果 `just` 没有加入 PATH，可以直接用绝对路径
& 'D:\DevEnv\just\just.exe' --list

# 编译 Debug
just build

# 编译 Release
just build-release

# 烧录 Debug 固件
just flash

# 编译并烧录 Debug
just deploy

# 格式化 C/C++ 源码
just format

# 格式检查 + 静态分析
just check

# 清理构建产物
just clean

# 完整重建 Debug
just rebuild
```

### 直接使用 OpenOCD

```bash
& 'D:\DevEnv\openocd\bin\openocd.exe' `
    -f 'D:/DevEnv/openocd/share/openocd/scripts/interface/cmsis-dap.cfg' `
    -f 'D:/DevEnv/openocd/share/openocd/scripts/target/stm32h7x.cfg' `
    -c "program build/Debug/TEST_VSCODE_LPUART1_2.elf verify reset exit"
```

### 调试

1. 在 VS Code 里安装 `Cortex-Debug` 扩展（如果还没装）。
2. 先执行 `just build`，或者直接按 `F5`，调试配置会自动先构建 Debug。
3. 选择 `Debug STM32H743 (OpenOCD)`，然后按 `F5` 启动。
4. 调试器会自动用 OpenOCD 连接 CMSIS-DAP，加载 `build/Debug/TEST_VSCODE_LPUART1_2.elf`，并停在 `main`。

如果你只是想单独烧录，不进调试，就执行 `just flash`。

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

| 烧录器类型 | 配置文件             | 适用场景                      |
| ---------- | -------------------- | ----------------------------- |
| CMSIS-DAP  | `cmsis-dap.cfg`      | DAPLink、HS-Link、WCH-Link 等 |
| J-Link     | `stm32h7_jlink.cfg`  | Segger J-Link / J-Link OB     |
| ST-Link    | `stm32h7_stlink.cfg` | ST-Link V2/V3                 |

当前项目默认使用 `D:/DevEnv/openocd/share/openocd/scripts/interface/cmsis-dap.cfg` 和 `D:/DevEnv/openocd/share/openocd/scripts/target/stm32h7x.cfg`。

---

## 引脚配置

| 功能       | 引脚 | 模式     |
| ---------- | ---- | -------- |
| LPUART1_TX | PA9  | 复用推挽 |
| LPUART1_RX | PA10 | 复用输入 |

---

## 参考资源

- [STM32H743 Reference Manual (RM0433)](https://www.st.com/resource/en/reference_manual/rm0433-stm32h742-stm32h743753-and-stm32h750-value-line-advanced-armbased-32bit-mcus-stmicroelectronics.pdf)
- [STM32H743 Datasheet](https://www.st.com/resource/en/datasheet/stm32h743xi.pdf)
- [FreeRTOS Documentation](https://www.freertos.org/Documentation/RTOS_book.html)

---

## 许可证

MIT License
