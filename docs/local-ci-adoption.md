# 本地 CI 接入指南

## 目标

在多个 STM32 仓库之间复用同一套本地 CI 基座，而不是每换一个芯片就重写一遍脚本。

## 企业标准

每个项目都应该暴露同一个标准入口：

```bash
python3 scripts/ci/main.py <subcommand>
```

Windows 对应：

```powershell
py -3 scripts/ci/main.py <subcommand>
```

这条接口应该被统一用于：

- 开发者终端
- 云端 CI
- Git Hook
- IDE Task

## 推荐分层

建议职责划分如下：

- `scripts/ci/main.py`：标准入口
- `scripts/ci/*.py`：可复用执行逻辑
- `.local-ci/config.json`：项目级配置
- `Justfile`：开发者快捷入口
- `lefthook.yml`：Git 生命周期集成
- `.vscode/tasks.json`：IDE 便利层

## 关于 `just`

很多企业会使用 `make`、`just`、`invoke`、`task` 这一类工具作为开发者快捷入口，这是很常见也很推荐的做法。

但要注意：

- `just` 更适合做人类友好的命令层
- 它不一定适合作为企业唯一标准入口
- 真正的企业标准入口，更适合选用可直接被本地终端和云端 CI 共用的命令

在本仓库里，我们选择：

- Python CLI 作为企业标准入口
- `just` 作为开发者快捷层
- VS Code Task 作为 IDE 快捷层

这样做的原因是：

- Linux 云端不必依赖 `just`
- Windows 本地仍然可以方便地用 `just`
- IDE 与命令行共用同一套底层逻辑

## 最小项目接入面

接入一个新的芯片或项目时，优先只改：

- `.local-ci/config.json`

常见需要调整的项目级字段：

- 项目名
- preset 名称
- 产物基名
- format / lint 路径范围
- OpenOCD target 配置

## 不应该要求项目去做的事

正常项目接入时，不应该要求开发者：

- 重写 `scripts/ci/*.py`
- 修改 `cmake/` 框架文件
- 把 CI 逻辑重复写进 VS Code Task
- 在 Hook 里写机器私有逻辑

## 推荐落地步骤

1. 安装所需工具，并确保工具在 `PATH` 中，或者提前配置好工具环境变量。
2. 复用或接入共享本地 CI 基座。
3. 为项目提供 `.local-ci/config.json`。
4. Windows 下执行 `py -3 scripts/ci/main.py init`，Linux 下执行 `python3 scripts/ci/main.py init`。
5. 继续验证 `build`、`size`、`check`。

## 验收清单

- `main.py init` 在全新 clone 上可通过
- `main.py build --preset Debug` 能产出 `.elf`、`.map`、`.bin`、`.hex`
- `main.py build --preset Release` 能产出同样的产物集合
- `main.py check` 本地可通过
- `pre-commit` 保持轻量
- `pre-push` 在完整质量门失败时能阻止推送

## IDE 策略

允许并推荐 VS Code Task 作为便利层，但它必须调用同一个 Python 标准入口。

团队不应该把 VS Code Task 当成唯一 CI 入口。
