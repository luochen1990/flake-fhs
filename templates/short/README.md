# Short Template

简短命名模板，包含完整的 NixOS 系统配置功能。

## 项目结构

```
.
├── pkgs/
│   └── hello/              # 自定义包
│       └── package.nix
├── shells/
│   ├── default.nix         # 默认开发环境
│   └── python.nix         # Python 开发环境
├── apps/
│   └── greeting/          # 示例应用程序
│       └── default.nix
├── flake.nix              # 项目配置
└── README.md              # 本文档
```

## 功能特性

- ✅ 自动包发现和构建
- ✅ 多开发环境支持
- ✅ 应用程序封装
- ✅ 跨平台支持

## 快速开始

```bash
# 创建新项目
nix flake init --template github:luochen1990/Nix-FHS#short

# 构建包
nix build .#hello

# 进入开发环境
nix develop .#default
nix develop .#python

# 运行应用
nix run .#greeting
```

## 扩展指南

- **新包**：在 `pkgs/` 下创建 `*.nix`
- **新环境**：在 `shells/` 下创建 `*.nix`
- **新应用**：在 `apps/` 下创建目录和 `default.nix`