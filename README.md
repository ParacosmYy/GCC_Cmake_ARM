# GCC_Cmake_ARM

> ARM GCC + CMake 嵌入式开发模板仓库。

本仓库用于沉淀 STM32 / Cortex-M 项目的 GCC、CMake、OpenOCD、VSCode 和本地 CI 配置。它更适合作为工程模板仓库，而不是具体业务项目仓库。

## 仓库定位

| 项目 | 说明 |
|------|------|
| 方向 | STM32 / Cortex-M 工程模板 |
| 构建系统 | CMake + Ninja |
| 编译器 | ARM GNU Toolchain |
| 调试 | OpenOCD / CMSIS-DAP / J-Link / ST-Link |
| 推荐用途 | 新项目起步、模板复用、工具链配置参考 |

## 分支说明

| 分支 | 说明 |
|------|------|
| `master` | 仓库说明和模板索引 |
| `H743XIH_DAP` | STM32H743XIH6 项目模板，CMSIS-DAP 烧录器配置 |
| `template/stm32-local-ci-extract` | STM32 本地 CI 模板提取分支 |
| `backup/hook-local-ci` | 本地 hook / CI 备份分支 |

> 旧文档中提到的 `GCC_Toolchain` 分支当前未出现在分支列表中，后续如果恢复，应补充到这里。

## 推荐使用方式

```bash
# 拉取 H743 模板
git clone -b H743XIH_DAP https://github.com/ParacosmYy/GCC_Cmake_ARM.git

# 拉取本地 CI 模板
git clone -b template/stm32-local-ci-extract https://github.com/ParacosmYy/GCC_Cmake_ARM.git
```

## 适合放在本仓库的内容

- `CMakeLists.txt` 模板；
- 交叉编译工具链文件；
- OpenOCD 配置；
- VSCode `tasks.json` / `launch.json`；
- 本地格式化、静态检查、构建脚本；
- 新工程 README 模板。

## 后续整理建议

如果与 `EmbeddedProject-Folder-Template` 合并，建议新仓库命名为：

```text
GS_Embedded_Template
```

合并后目录建议：

```text
GS_Embedded_Template/
├── project-folder-template/     # 工程归档目录结构模板
├── arm-gcc-cmake/               # ARM GCC + CMake 工程模板
├── openocd/                     # 烧录器配置
├── vscode/                      # VSCode 工作区配置
├── ci/                          # 本地 CI / GitHub Actions 模板
└── README.md
```
