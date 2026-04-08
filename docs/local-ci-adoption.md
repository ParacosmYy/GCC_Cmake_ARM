# 本地 CI 接入指南

## 目标

在多个 STM32 项目之间复用同一套本地 CI 基座，同时保持 CubeMX 框架不被破坏。

## 标准入口

标准入口统一为：

```bash
python3 Scripts/ci/main.py <subcommand>
```

Windows 对应：

```powershell
py -3 Scripts/ci/main.py <subcommand>
```

## 目录约定

CubeMX 生成内容：

- `Core/`
- `Drivers/`
- `Middlewares/`

用户自维护内容：

- `App/`
- `Bsp/`
- `Service/`
- `Config/`
- `Board/`
- `Scripts/`

## 哪些文件是通用的

下面这些通常可以跨 STM32 项目复用：

- `Scripts/ci/*.py`
- `Scripts/hooks/*.py`
- `Justfile`
- `lefthook.yml`
- `.local-ci/config.schema.json`
- `.vscode/tasks.json`

## 哪些文件是项目级的

下面这些通常需要按项目修改：

- `.local-ci/config.json`
- `.vscode/settings.json`
- `.vscode/launch.json`
- `README.md`

## 项目最小修改面

新项目接入时，优先只改：

- `.local-ci/config.json`
- `.vscode/settings.json`
- `.vscode/launch.json`

## 本地 CI 当前拦截范围

当前已经接入规范拦截的用户目录：

- `App/`
- `Bsp/`
- `Service/`
- `Config/`
- `Board/`
- `Scripts/` 中的 Python 脚本

过渡期保留：

- `Core/Inc/main.h`
- `Core/Src/main.c`
