# Simple Project Template

这是一个使用 Nix FHS 的简单项目模板，展示了基本的包管理、开发环境和应用程序。

## 项目结构

```
.
├── pkgs/
│   └── hello/              # 自定义包
│       └── package.nix
├── shells/
│   ├── default.nix         # 默认开发环境
│   └── rust.nix           # Rust 开发环境
├── apps/
│   └── greeting/          # 示例应用程序
│       └── default.nix
└── lib/
    └── utils.nix          # 工具函数库
```

## 使用方法

```bash
# 复制模板到新项目
nix flake init --template <Nix-FHS-url>#simple-project

# 构建包
nix build .#hello-custom

# 进入开发环境
nix develop .#default
nix develop .#rust

# 运行应用
nix run .#greeting

# 使用工具函数
nix eval .#lib.utils.strings.camelCase --apply 'f: f "hello-world"'
```

## 特性

- ✅ 自动包发现和构建
- ✅ 多开发环境支持
- ✅ 应用程序封装
- ✅ 工具函数库
- ✅ 跨平台支持