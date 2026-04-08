# 用户自维护代码布局

本仓库把手写代码统一放在用户自维护目录中，而不是直接散落到 CubeMX 生成目录里。

- `App/`：应用层入口
- `Bsp/`：板级支持
- `Service/`：服务层
- `Config/`：配置层
- `Board/`：板级差异
- `Scripts/`：自动化脚本

CubeMX 生成内容仍保留在 `Core/`、`Drivers/`、`Middlewares/` 中。
