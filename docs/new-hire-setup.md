# 新人入职环境搭建指南

## 先讲结论

- 企业一般不会让新人从一个空文件夹开始手搓 STM32 工程。
- 更常见的做法是准备一个“模板仓库”或“项目基座”，新人拿到的是一个已经能构建、能检查、能调试的工程。
- 在 STM32 项目里，CubeMX 主要负责 MCU 初始化、时钟、外设和中断等底座配置；工程模板还要负责构建系统、CI、IDE 配置、代码分层和团队约定。
- 对于本仓库来说，`TEST_VSCODE_LPUART1_2.ioc`、`Core/`、`Drivers/`、`Middlewares/`、启动文件和链接脚本都已经提交，所以它不是“只有模板文件”的空壳，而是一个可以直接派生的工程基座。
- 只上传模板文件、却不带 CubeMX 生成结果，通常不够新人直接开工，除非团队还有一套非常稳定的自动生成流水线，并且严格锁定 CubeMX 版本、Pack 版本和生成参数。

## 从 0 开始，推荐的落地方式

如果你问的是“新人拿到一个新 STM32 项目，怎么从 0 走到能编译、能跑”，推荐按下面的顺序来。

### 1. 先准备统一工具环境

本仓库的本地开发环境默认围绕 Windows + GCC + CMake + VS Code 展开，工具通常放在：

```text
D:\DevEnv
```

常见组件包括：

- `cmake`
- `ninja`
- `llvm`
- `cppcheck`
- `lefthook`
- `openocd`
- `GNU-tools-for-STM32`
- `just`
- `git`

### 2. 再拿到“工程基座”

企业里常见有两种做法。

第一种是“模板仓库”：

- 仓库里已经有 `.ioc`
- 仓库里已经有 CubeMX 生成出来的 `Core/`、`Drivers/`、`Middlewares/`
- 仓库里已经有 `CMakeLists.txt`、`CMakePresets.json`、`Scripts/ci`、`lefthook.yml`、`.vscode/`
- 新项目从这个仓库复制、fork，或者用它创建新仓库

第二种是“模板仓库 + 生成流程”：

- 仓库只保存模板规则、生成脚本和少量骨架
- 新项目按固定脚本重新生成 CubeMX 输出
- 这种方式能做，但要求版本控制非常严格

对 STM32 团队来说，第一种通常更省心，也更适合新人上手。

### 3. 如果项目是新板子或新外设，再打开 CubeMX

CubeMX 的职责是“生成底座”，不是“承包整个工程结构”。

你通常要在 CubeMX 里做的是：

- 选择 MCU 或开发板
- 配时钟树
- 配 GPIO、串口、定时器、DMA、FreeRTOS 等外设
- 生成初始化代码和必要的 HAL/CMSIS 关联文件

你通常不应该让 CubeMX 接管的是：

- `App/`
- `Bsp/`
- `Service/`
- `Config/`
- `Board/`
- `Scripts/`
- CI、Hook、IDE 任务配置

也就是说，CubeMX 负责“芯片怎么起来”，模板仓库负责“工程怎么长期维护”。

### 4. 让项目先能初始化

本仓库里，第一次进入项目后建议先跑初始化任务：

```powershell
Run Task -> ci: init
```

这个动作主要做两件事：

- 检查本机工具链是否齐全
- 安装 Lefthook

### 5. 再做构建和检查

建议顺序是：

1. `Run Task -> ci: build`
2. `Run Task -> ci: check`
3. 如需要完整扫描，再跑 `Run Task -> ci: check-full`

如果你更习惯命令行，也可以直接调用：

```powershell
py -3 Scripts/ci/main.py init
py -3 Scripts/ci/main.py build --preset Debug
py -3 Scripts/ci/main.py check
py -3 Scripts/ci/main.py check --mode full
```

## 企业一般会上传什么

如果是一个比较成熟的 STM32 团队，通常不会只给“几份模板文件”，而是会给一个完整可复用的基座。

### 通常会包含

- `.ioc`
- `Core/`
- `Drivers/`
- `Middlewares/`
- 启动文件，例如 `startup_stm32h743xx.s`
- 链接脚本，例如 `STM32H743XX_FLASH.ld`
- 构建系统，例如 `CMakeLists.txt`、`CMakePresets.json`
- 本地 CI 与脚本，例如 `Scripts/ci/`、`Scripts/hooks/`
- IDE 配置，例如 `.vscode/`
- 团队约定，例如 `README.md`、`docs/`

### 通常不会让新人一开始就自己拼的东西

- 手工创建整个 CubeMX 工程骨架
- 手工补齐所有 HAL/CMSIS 生成文件
- 手工猜测编译器、链接器、OpenOCD、cppcheck 的路径
- 手工搭建 VS Code Task、Lefthook 和质量门

### 为什么模板不建议太“轻”

如果模板里只有少量说明文档，而没有生成后的工程内容，新人会遇到这些问题：

- 无法直接编译
- 不知道哪些文件是 CubeMX 生成的，哪些是团队手写的
- CubeMX 版本差异会导致生成结果漂移
- 目录结构和 CI 规则无法复用

所以，工程模板的核心价值不是“文件少”，而是“新人一 clone 就能跑”。

## 本仓库的实际分层

这里的分层，基本就是“CubeMX 生成层”和“用户自维护层”分开。

### CubeMX 生成层

- `Core/`
- `Drivers/`
- `Middlewares/`

### 用户自维护层

- `App/`
- `Bsp/`
- `Service/`
- `Config/`
- `Board/`
- `Scripts/`

### 当前约定

- 长期维护代码尽量放到用户自维护层
- `Core/` 目前只保留过渡期入口修改
- `Drivers/` 和 `Middlewares/` 不要塞进长期业务代码

## 新人第一天最实用的动作

如果你是刚加入项目，建议按下面这个顺序走。

1. 确认 `D:\DevEnv` 里工具都装好了。
2. 打开项目仓库。
3. 先跑 `Run Task -> ci: init`。
4. 再跑 `Run Task -> ci: build`。
5. 再跑 `Run Task -> ci: check`。
6. 如果要接板调试，再看 `Run Task -> ci: flash` 或 `Debug STM32 (OpenOCD)`。
7. 真正写业务逻辑时，把代码放到 `App/`、`Bsp/`、`Service/`、`Config/`、`Board/`。

## 如果你真的是从“空项目”起步

如果团队现在还没有任何模板仓库，而是要你从零建立一个新 STM32 项目，那么推荐做法不是让每个新人自己摸索，而是先由一个人把“基座”搭好，再沉淀成模板。

最小可复用基座一般应该包含：

- 一个明确版本的 `.ioc`
- CubeMX 生成结果
- 启动文件和链接脚本
- CMake 构建配置
- CI 脚本和 Lefthook
- VS Code 配置
- 板级和应用层目录分层

然后再把这个基座复制成新项目。

## 和本仓库相关的补充说明

- 如果你想看本地 CI 怎么接入，优先看 `docs/local-ci-adoption.md`
- 如果你想看代码为什么分到 `App/`、`Bsp/`、`Service/` 这些目录，优先看 `README.md`
- 如果你想确认命令入口，优先看 `Scripts/ci/main.py`

## 一句话总结

对 STM32 团队来说，合理的做法通常不是“新人自己从零拼一个 CubeMX 工程”，而是“企业先提供一个可运行的模板基座，新人基于它做芯片配置和业务开发”。
