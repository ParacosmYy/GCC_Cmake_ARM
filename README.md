# STM32 本地 CI 模板

这是一套给 STM32 小到中型团队使用的本地 CI 模板层。

它的目标很明确：

- 统一 `VS Code + 本地命令 + Lefthook`
- 让新人能自己把模板层接进现有 STM32 项目
- 尽量不往项目里塞额外长期基础设施

## 1. 三层职责

这套流程固定分成三层：

1. `DevEnv`
   - 团队统一工具环境
   - 先装环境，再谈项目接入
2. 当前模板分支
   - 只负责交付模板层
   - 不承担 STM32 参考工程职责
3. 目标 STM32 项目仓库
   - 自己维护 `.ioc`、`Core/`、`Drivers/`、启动文件、链接脚本、`CMakeLists.txt`、`CMakePresets.json`
   - 模板导入后，项目层仍然归项目自己维护

团队规则固定为：

- 不要让 CubeMX 直接往这个模板仓库里生成工程
- 要先在目标项目仓库根目录生成 STM32 工程层
- 再把本地 CI 模板层导入到同一个根目录

## 2. 先统一环境

拿到团队统一的 `DevEnv` 压缩包后，先执行：

```powershell
D:\DevEnv\install_env.ps1
```

执行完成后，关闭并重新打开终端或 VS Code。

至少确认这些命令能直接运行：

- `cmake`
- `ninja`
- `clangd`
- `clang-format`
- `cppcheck`
- `arm-none-eabi-gcc`
- `arm-none-eabi-gdb`
- `openocd`

## 3. 新项目的官方接入顺序

1. 新建目标 STM32 项目仓库
2. 在目标项目仓库根目录用 CubeMX 生成工程层
3. 确保项目根目录至少有这些内容
   - `.ioc`
   - `Core/`
   - `Drivers/`
   - `CMakeLists.txt`
   - `CMakePresets.json`
4. 回到模板仓库，双击：

```text
install-local-ci.bat
```

也可以直接用命令行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-local-ci.ps1 -Mode Install -TargetProject <目标项目路径>
```

5. 导入完成后，在目标项目根目录执行：

```powershell
py -3 Scripts/ci/main.py init
py -3 Scripts/ci/main.py build --preset Debug
py -3 Scripts/ci/main.py check
```

## 4. 模板会导入什么

模板层会导入这些内容：

- `Scripts/ci/`
- `Scripts/hooks/`
- `.vscode/tasks.json`
- `.vscode/launch.json`
- `.vscode/settings.json`
- `.clangd`
- `.clang-format`
- `lefthook.yml`

同时会写入模板版本锚点：

- `Scripts/ci/template-version.json`

这就是后续判断“项目是否已经接入过模板”的依据。

## 5. 现在不再保留 `.local-ci/`

新的模型里，目标项目中不再长期保留 `.local-ci/`。

也就是说，安装完成后的项目里不再维护：

- `.local-ci/config.json`
- `.local-ci/template-version.json`
- `.local-ci/backup-last/`
- `.local-ci/.txn/`
- `.local-ci/logs/`
- `.local-ci/installer-state.json`

如果是旧项目升级：

- 安装器会尽量读取旧 `.local-ci/config.json` 里的 OpenOCD 配置
- 成功后会清理旧 `.local-ci` 遗留内容
- 如果目录已经空了，会自动删除

## 6. 配置现在从哪里来

这版模板不再依赖项目级独立配置文件。

默认规则如下：

- 项目名：优先从 `CMakeLists.txt` 推导，读不到再回退到仓库目录名
- 产物名：优先从 `.vscode/launch.json` 的 `executable` 推导，读不到再回退到项目名
- OpenOCD `interface / target`：从 `.vscode/launch.json` 的 `Debug STM32 (OpenOCD)` 配置读取
- `build.root`：固定为 `build`
- `presets`：固定为 `Debug / Release`
- `flash.default_preset`：固定为 `Debug`
- `quality.format / lint`：固定使用模板默认规则

这意味着：

- 项目差异化入口更少
- 升级模板层更轻
- 项目级自定义质量规则不再作为默认能力保留

## 7. 现在有哪些模式

安装器只保留三种模式：

### Install

首次把模板层接入项目。

- 目标项目不应已有 `Scripts/ci/template-version.json`
- 更适合新项目首次接入

### Upgrade

把已有项目的模板层升级到当前版本。

- 目标项目应已接入过模板
- 会刷新模板拥有文件
- 会按规则合并 `.vscode/settings.json` 和 `.vscode/launch.json`

### Repair

当模板层文件被误删、误改时补回。

- 不碰 STM32 工程层
- 只修模板层

### Preview

任意模式都可以加 `-Preview`。

它只显示：

- 会新增什么
- 会替换什么
- 会合并什么
- 会清理什么旧文件

不会真正修改文件。

## 8. 失败恢复和日志

这版模板只保留“最小失败自恢复”：

- 执行开始前，脚本会在系统临时目录写一份事务快照
- 如果执行中途失败，脚本会自动恢复到本次执行前的状态
- 成功后不会在项目里留下 `backup-last`

长期回退策略固定为：

- 成功后的回退靠 `Git`
- 不再提供脚本级 `Rollback` 模式

详细诊断日志会写到系统临时目录，例如：

```text
%TEMP%\stm32-local-ci\<project-id>\last-run.log
```

正常交互界面只显示中文提示，不会把 PowerShell 堆栈直接甩给新人。

## 9. 向导会问什么

双击 `install-local-ci.bat` 后，中文向导会一步一步询问：

- 模式：`Install / Upgrade / Repair`
- 目标项目根目录
- 是否只做预览
- 是否需要 `-Force`
- 芯片族：`H7 / G4 / F4 / 其他`
- 调试器接口：`CMSIS-DAP / ST-Link / J-Link / 其他`

向导会优先帮你做模式判断。

例如：

- 已经接入过模板，却选了 `Install`
- 明明是首次接入，却选了 `Upgrade`

它会先给出中文建议，让你切换模式，而不是直接抛底层报错。

## 10. 常见排查

### `cmake` / `clangd` 找不到

先重新执行：

```powershell
D:\DevEnv\install_env.ps1
```

然后重新打开终端或 VS Code。

### 选错模式

记住这个简单规则：

- 没接入过模板：`Install`
- 已接入，想更新：`Upgrade`
- 模板层坏了，想补回：`Repair`

### 烧录配置不对

优先检查：

- `.vscode/launch.json`
- `Debug STM32 (OpenOCD)` 这一项
- `configFiles` 里的 `interface/*.cfg` 和 `target/*.cfg`

### 旧项目为什么还提到 `.local-ci`

因为安装器会兼容读取旧布局，帮助你迁移。

但新模型下，成功迁移后的目标是：

- 项目里不再长期保留 `.local-ci/`
- 长期配置不再靠独立 JSON 文件驱动


