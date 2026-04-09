# Scripts

`Scripts/ci/` 是团队统一的本地 CI 入口实现。

标准入口固定为：

```powershell
py -3 Scripts/ci/main.py <subcommand>
```

对团队公开的主命令只有：

- `init`
- `build`
- `check`
- `flash`

`Scripts/hooks/` 是 `Lefthook` 调用的脚本包装层。

当前默认只安装 `pre-commit`，不默认安装 `pre-push`。
