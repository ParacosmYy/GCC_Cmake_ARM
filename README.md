# STM32 Local CI Template

`template/stm32-local-ci-extract` 是面向 STM32 嵌入式工程的本地 CI 模板分支，用于把构建、格式检查、基础静态检查和提交前验证流程抽取成可复制的工程能力。

## 项目定位

| 项目 | 说明 |
| --- | --- |
| 类型 | STM32 本地 CI 模板 |
| 适用对象 | STM32 / Cortex-M 裸机或 RTOS 工程 |
| 核心目标 | 在提交前发现构建和基础质量问题 |
| 使用方式 | 复制模板到目标工程并按芯片配置适配 |
| 分支职责 | 沉淀可复用 CI 脚本、Hook、质量门禁示例 |

## CI 覆盖范围

建议模板至少覆盖以下能力：

- 命令行构建验证。
- 编译警告收集。
- 格式化检查或格式化入口。
- 关键目录结构检查。
- 链接产物和 MAP 文件生成检查。
- 可选的静态分析入口，例如 `cppcheck` 或编译器诊断增强。

## 推荐目录结构

```text
ci-template/
├── scripts/
│   ├── build.ps1
│   ├── clean.ps1
│   ├── check-format.ps1
│   └── verify.ps1
├── hooks/
│   └── pre-commit
├── cmake/
│   └── toolchain.cmake
└── docs/
    └── ci-guide.md
```

## 接入流程

1. 将 `scripts/`、`hooks/`、必要的 `cmake/` 模板复制到目标工程。
2. 修改工具链路径、芯片型号、链接脚本和构建目录。
3. 本地执行完整验证命令。
4. 将验证命令写入 README 或开发规范。
5. 再接入 Git Hook 或 GitHub Actions。

## 推荐命令

```powershell
./scripts/clean.ps1
./scripts/build.ps1
./scripts/check-format.ps1
./scripts/verify.ps1
```

如果目标工程暂时没有完整脚本，也建议至少保留一个统一入口：

```powershell
./scripts/verify.ps1
```

## 质量门禁

| 门禁 | 要求 |
| --- | --- |
| 构建 | 干净环境可一键构建 |
| 警告 | 新增警告需要解释或修复 |
| 路径 | 脚本禁止绑定个人绝对路径 |
| 配置 | 芯片型号、链接脚本、工具链集中配置 |
| 速度 | 本地验证应足够快，适合提交前执行 |

## 适配原则

- 模板只提供标准流程，不强行绑定具体业务代码。
- 不同 MCU 型号通过配置文件区分，不复制多套脚本。
- 本地 CI 与远端 CI 使用同一套命令，减少“本地能过、线上失败”的差异。
- Hook 只做必要检查，耗时任务建议放到显式 `verify` 命令。

## 维护边界

该分支是模板来源，不是业务工程。任何项目定制逻辑应在目标项目中维护；只有具有复用价值的脚本、规范和检查项才应回流到该模板分支。