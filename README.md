# STM32 本地 CI 与自定义代码框架

本仓库采用 Python 优先的本地 CI 设计，服务于：

- Windows 本地 GCC + CMake 开发
- Linux 云端 CI
- 后续跨芯片项目复用

## 企业标准入口

企业标准入口是：

```bash
python3 Scripts/ci/main.py <subcommand>
```

Windows 推荐写法：

```powershell
py -3 Scripts/ci/main.py <subcommand>
```

例如：

```powershell
py -3 Scripts/ci/main.py init
py -3 Scripts/ci/main.py build --preset Debug
py -3 Scripts/ci/main.py check
```

## 开发者与 IDE 入口

为了降低团队上手成本，仓库同时保留两层便利入口：

- 开发者快捷层：`just ...`
- IDE 便利层：VS Code Task

但它们都只是外壳，底层都调用同一个 Python 主入口。

## 自定义代码目录规范

除 CubeMX 生成内容外，用户自维护代码统一放在这些目录：

- `App/`：应用层流程与业务入口
- `Bsp/`：板级支持与外设封装
- `Service/`：可复用服务层
- `Config/`：用户自维护配置
- `Board/`：板级定义与板卡差异
- `Scripts/`：CI、Hook、开发自动化脚本

CubeMX 生成内容继续保留在：

- `Core/`
- `Drivers/`
- `Middlewares/`

## 当前本地 CI 会拦截什么

当前本地 CI 已经会对这些用户自维护目录做代码规范拦截：

- `App/`
- `Bsp/`
- `Service/`
- `Config/`
- `Board/`
- `Scripts/` 中的 Python 脚本
- 过渡期保留 `Core/Inc/main.h`
- 过渡期保留 `Core/Src/main.c`

当前拦截能力包括：

- `pre-commit`
  - staged diff whitespace / conflict 检查
  - JSON 配置校验
  - 对手写 C/C++ 文件执行 `clang-format` 自动格式化并回暂存
  - 对 `Scripts/` 下的 Python 脚本执行语法校验
- `pre-push`
  - 执行完整 `check`
- `check`
  - `format --check`
  - `lint`
  - `python-check`
  - `build Debug`
  - `build Release`
  - `size`

## VS Code 核心 Task

考虑到团队目前是 GCC 初始开发阶段，VS Code 中保留了精简的核心 Task：

- `ci: init`
- `ci: build`
- `ci: build-release`
- `ci: check`
- `ci: flash`
- `ci: clean`

这些 Task 都直接调用 `Scripts/ci/main.py`。

## 项目级配置

项目级差异集中在：

- [.local-ci/config.json](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/.local-ci/config.json)

这个文件控制：

- 项目名
- preset 映射
- 固件产物名
- 代码规范检查范围
- OpenOCD 默认配置

## 跨芯片复用

换到 G4、F4 或其他 STM32 项目时，正常只需要改：

- `.local-ci/config.json`
- `.vscode/settings.json` 里的项目级 ELF / 调试配置

不应该因为换芯片就重写 `Scripts/ci/*.py`。

## 接入与团队规范

详见：

- [docs/local-ci-adoption.md](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/docs/local-ci-adoption.md)
- [docs/new-hire-setup.md](/d:/Workplace/Embeded_Workplace/H7_TEST_LPUART1/TEST_VSCODE_LPUART1_2/docs/new-hire-setup.md)
