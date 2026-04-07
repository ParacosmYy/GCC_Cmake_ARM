# GCC CMake ARM 嵌入式开发仓库

本仓库包含基于 GCC + CMake 的 STM32 嵌入式开发模板和工具链配置。

---

## 分支说明

| 分支名 | 说明 |
|--------|------|
| `master` | 主分支，仅包含文档说明 |
| `H743XIH_DAP` | STM32H743XIH6 项目模板，CMSIS-DAP 烧录器配置 |
| `GCC_Toolchain` | Windows 下完整的 GCC ARM 开发工具链 |

---

## 快速开始

### 1. 克隆特定分支

```bash
# 获取 H743 项目模板
git clone -b H743XIH_DAP https://github.com/ParacosmYy/GCC-Cmake-ARM-.git

# 获取工具链
git clone -b GCC_Toolchain https://github.com/ParacosmYy/GCC-Cmake-ARM-.git DevEnv
```

### 2. 分支详情

#### H743XIH_DAP 分支
- **芯片型号**: STM32H743XIH6 (TFBGA240 封装)
- **烧录器**: CMSIS-DAP (DAPLink) 兼容调试器
- **构建系统**: CMake + Ninja
- **RTOS**: FreeRTOS
- **特性**: LPUART + BDMA 传输示例

#### GCC_Toolchain 分支
- **GCC**: ARM GNU Toolchain (arm-none-eabi-gcc)
- **构建工具**: CMake, Ninja
- **调试工具**: OpenOCD
- **代码检查**: Cppcheck
- **Git 钩子**: Lefthook
- **其他**: LLVM, Just 命令运行器

---

## 切换芯片/烧录器指南

### 修改芯片型号
1. 替换 `startup_stm32h743xx.s` 为对应芯片的启动文件
2. 替换 `STM32H743XX_FLASH.ld` 为对应芯片的链接脚本
3. 修改 `.ioc` 文件或使用 STM32CubeMX 重新生成
4. 更新 `CMakeLists.txt` 中的项目名称

### 修改烧录器类型
在 `GCC_Toolchain` 分支的 OpenOCD 配置目录中：
- 选择对应芯片系列的 `.cfg` 文件
- 选择对应烧录器类型的配置文件：
  - `*_cmsis_dap.cfg` - CMSIS-DAP/DAPLink
  - `*_jlink.cfg` - J-Link
  - `*_stlink.cfg` - ST-Link

---

## 许可证

MIT License
