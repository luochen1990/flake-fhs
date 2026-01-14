# Zero Template

最小化模板，仅包含 `flake.nix` 文件，所有目录结构留给用户根据需要自己创建。

## 快速开始

```bash
# 创建新项目
nix flake init --template github:luochen1990/Nix-FHS#zero
```

## 项目结构

初始结构：
```
.
└── flake.nix              # 项目配置
```

## 使用指南

此模板提供最基础的配置，您可以根据需要添加以下目录：

### 添加包管理
```
mkdir pkgs
# 在 pkgs/ 下创建 <name>/package.nix 文件
```

### 添加开发环境
```
mkdir shells
# 在 shells/ 下创建 <name>.nix 文件
```

### 添加应用程序
```
mkdir apps
# 在 apps/ 下创建 <name>/default.nix 文件
```

### 添加 NixOS 模块
```
mkdir modules
# 在 modules/ 下创建目录，包含 options.nix 和 config.nix
```

### 添加系统配置
```
mkdir profiles
# 在 profiles/ 下创建 <name>/configuration.nix 文件
```

### 添加检查
```
mkdir checks
# 在 checks/ 下添加文件或目录
```

## 示例

### 创建一个简单的包
```bash
mkdir -p pkgs/my-tool
cat > pkgs/my-tool/package.nix << 'EOF'
{ stdenv, lib }:
stdenv.mkDerivation {
  pname = "my-tool";
  version = "1.0.0";
  src = ./src;
  meta.description = "My custom tool";
}
EOF
```

### 创建一个开发环境
```bash
cat > shells/default.nix << 'EOF'
{ pkgs, ... }:
{
  packages = with pkgs; [
    git
  ];
}
EOF
```

## 特性

- ✅ 最小化初始配置
- ✅ 完全自定义的目录结构
- ✅ 逐步添加所需功能
- ✅ 跨平台支持

## 为什么选择此模板？

适合以下场景：
- 需要完全控制项目结构的用户
- 只需要特定功能的简单项目
- 学习 Nix FHS 框架的用户
- 从零开始构建自定义项目
