# STM32 本地 CI 与代码框架说明

本仓库采用 Python 优先的本地 CI 方案，目标是同时服务于：

- Windows 本地 GCC + CMake 开发
- Linux 云端 CI
- 团队统一的 VS Code 开发体验
- 后续跨芯片项目复用

## 企业标准入口

企业标准入口统一为：

```bash
python3 Scripts/ci/main.py <subcommand>
```

Windows 推荐写法：

```powershell
py -3 Scripts/ci/main.py <subcommand>
```

常用示例：

```powershell
py -3 Scripts/ci/main.py init
py -3 Scripts/ci/main.py build --preset Debug
py -3 Scripts/ci/main.py check
py -3 Scripts/ci/main.py check --mode full
py -3 Scripts/ci/main.py flash
```

## 分层说明

- 标准入口：`Scripts/ci/main.py`
- 开发者快捷层：`just ...`
- Git Hook：`lefthook`
- IDE 便利层：VS Code Task

注意：

- 真正的 CI 逻辑只保留在 `Scripts/ci/*.py`
- `just`、VS Code Task、hook 都只是外壳
- 云端 CI 应直接调用 Python 标准入口

## 目录约定

除 CubeMX 生成内容外，手写代码统一放在以下目录：

- `App/`：应用层流程与任务
- `Bsp/`：板级支持与外设封装
- `Service/`：可复用服务
- `Config/`：项目配置
- `Board/`：板卡差异与板级定义
- `Scripts/`：CI、Hook 与开发自动化脚本

CubeMX 生成目录保持原样：

- `Core/`
- `Drivers/`
- `Middlewares/`

## 本地 CI 当前拦截范围

当前质量门会检查：

- `App/`
- `Bsp/`
- `Service/`
- `Config/`
- `Board/`
- `Scripts/` 下的 Python 脚本
- 过渡期保留 `Core/Inc/main.h`
- 过渡期保留 `Core/Src/main.c`

当前检查项包括：

- `pre-commit`
  - staged diff whitespace / conflict 检查
  - JSON 配置校验
  - 对手写 C/C++ 文件执行 `clang-format`
  - 对 `Scripts/` 下的 Python 脚本做语法校验
- `pre-push`
  - 执行完整 `check --mode full`
- `check`
  - `format --check`
  - `lint`
  - `python-check`
  - `build Debug`
  - `build Release`
  - `size`

## 本地快检与完整检查

日常开发推荐：

```powershell
py -3 Scripts/ci/main.py check
```

说明：

- 默认是本地快速模式
- 优先检查变更过的手写 C/C++ 文件
- 如果当前变更不涉及手写 C/C++，则跳过本地 `cppcheck`

推送前或完整自检推荐：

```powershell
py -3 Scripts/ci/main.py check --mode full
```

## VS Code Task

考虑到团队当前是 GCC 初始开发团队，仓库保留了精简的 VS Code Task：

- `ci: init`
- `ci: build`
- `ci: build-release`
- `ci: check`
- `ci: check-full`
- `ci: flash`
- `ci: clean`

说明：

- 这些 Task 全部调用 `Scripts/ci/main.py`
- `ci: build`、`ci: build-release`、`ci: check`、`ci: check-full` 已接入 `problemMatcher`
- 构建、格式、静态检查中的关键报错会进入 VS Code `Problems` 面板

## 团队工具目录约定

团队当前统一约定工具目录为：

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

`.vscode/settings.json` 当前按这一团队约定提供默认路径。

## 哪些文件是通用的

下面这些通常可以在 STM32 项目之间复用：

- `Scripts/ci/*.py`
- `Scripts/hooks/*.py`
- `Justfile`
- `lefthook.yml`
- `.local-ci/config.schema.json`
- `.vscode/tasks.json`

## 哪些文件是项目级的

下面这些通常需要项目负责人按项目修改：

- `.local-ci/config.json`
- `.vscode/settings.json`
- `.vscode/launch.json`
- `README.md`

## 跨芯片复用建议

换到 G4、F4 或其他 STM32 项目时，原则上优先只改：

- `.local-ci/config.json`
- `.vscode/settings.json`
- `.vscode/launch.json`

不应因为换芯片就重写：

- `Scripts/ci/*.py`
- `Scripts/hooks/*.py`

## 诊断与排障

当前本地 CI 已具备这些诊断能力：

- 标题、日志、警告、错误、成功、总结使用统一颜色语义
- 失败时优先打印阶段信息
- `format`、`lint`、`python-check` 失败时会输出文件与行号摘要
- VS Code Task 会将 GCC 风格报错同步到 `Problems` 面板

如果需要查看完整 Python traceback，可临时执行：

```powershell
$env:LOCAL_CI_TRACEBACK=1
py -3 Scripts/ci/main.py check
```

## 更多说明

详见：

- `docs/local-ci-adoption.md`
- `docs/new-hire-setup.md`
