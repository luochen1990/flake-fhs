# Project Template

项目内嵌模板，适用于非 Nix 项目需要提供 Nix 包支持的场景。

## 项目结构

```
.
├── nix/                    # Nix 配置目录
│   ├── pkgs/              # 项目相关的 Nix 包
│   │   └── hello/         # 示例包
│   │       └── package.nix
│   ├── shells/            # 开发环境
│   │   └── default.nix    # 默认开发环境
│   ├── modules/           # NixOS 模块（可选）
│   ├── apps/              # 应用程序（可选）
│   ├── checks/            # 检查（可选）
│   └── ...                # 其他 Nix FHS 目录
├── flake.nix              # Nix flake 配置
├── src/                   # 项目源代码（示例）
├── package.json           # Node.js 项目配置（示例）
├── pyproject.toml         # Python 项目配置（示例）
└── README.md              # 项目文档
```

## 使用场景

适合以下场景：
- **Web 前端项目**：React、Vue、Angular 等前端框架项目
- **后端服务项目**：Python、Node.js、Go 等后端服务
- **全栈项目**：需要同时管理前端和后端的项目
- **工具链项目**：需要特定工具和环境的开发项目
- **混合项目**：传统项目需要逐步引入 Nix

## 快速开始

```bash
# 创建新项目
nix flake init --template github:luochen1990/Nix-FHS#project

# 进入开发环境
nix develop

# 构建项目包
nix build .#hello

# 运行示例程序
nix run .#hello
```

## 主要特性

### 📦 **项目包管理**
- 在 `nix/pkgs/` 下创建项目相关的 Nix 包
- 例如：构建工具、脚本、项目二进制等

### 🔧 **开发环境**
- 在 `nix/shells/` 下创建开发环境
- 包含项目所需的所有工具和依赖
- 支持语言特定的环境（Python、Node.js、Rust 等）

### 🚀 **项目集成**
- 项目源代码保持在根目录
- Nix 配置隔离在 `nix/` 目录
- 不干扰原有项目结构

### ✅ **质量检查**
- 在 `nix/checks/` 下添加检查
- 支持格式化、linting、测试等

## 示例：Node.js 项目

### 1. 创建项目结构
```bash
# 项目目录已存在
mkdir -p src
npm init -y  # 或者使用其他包管理器
```

### 2. 配置开发环境
```nix
# nix/shells/default.nix
{ pkgs, ... }:
{
  packages = with pkgs; [
    nodejs_20
    pnpm
    typescript
  ];
}
```

### 3. 添加构建脚本
```nix
# nix/apps/build/default.nix
{ pkgs, ... }:
{
  type = "app";
  program = "${pkgs.writeShellScript "build" ''
    cd $PRJ_ROOT
    pnpm install
    pnpm build
  ''}";
}
```

### 4. 使用
```bash
# 进入开发环境
nix develop

# 安装依赖
pnpm install

# 构建项目
pnpm build

# 或使用 Nix 应用
nix run .#build
```

## 示例：Python 项目

### 1. 配置开发环境
```nix
# nix/shells/default.nix
{ pkgs, ... }:
{
  packages = with pkgs; [
    python311
    poetry
  ];
}
```

### 2. 添加 Python 包
```nix
# nix/pkgs/my-app/package.nix
{ python311, pkgs, ... }:
python311.pkgs.buildPythonApplication {
  pname = "my-app";
  version = "1.0.0";
  src = ./.;
  pyproject = true;
  build-system = [ python311.pkgs.setuptools ];
}
```

### 3. 使用
```bash
# 进入开发环境
nix develop

# 安装依赖
poetry install

# 运行项目
poetry run python src/main.py
```

## 高级用法

### 添加 NixOS 模块
```bash
mkdir -p nix/modules/my-module
```

```nix
# nix/modules/my-module/options.nix
{ lib, ... }:
{
  options.my-module.enable = lib.mkEnableOption "My module";
}
```

### 添加应用程序
```nix
# nix/apps/deploy/default.nix
{ pkgs, ... }:
{
  type = "app";
  program = "${pkgs.writeShellScript "deploy" ''
    echo "Deploying to production..."
    # 部署脚本
  ''}";
}
```

## 最佳实践

1. **隔离配置**：将 Nix 配置放在 `nix/` 目录，保持项目根目录清晰
2. **逐步集成**：从开发环境开始，逐步添加其他功能
3. **版本管理**：使用 `nix flake update` 管理依赖
4. **文档完善**：为团队成员提供清晰的使用文档
5. **CI/CD 集成**：在 CI 系统中使用 Nix 保证环境一致性

## 与其他模板的区别

| 模板 | 适用场景 | 项目结构 |
|------|----------|----------|
| `std` | 完整 NixOS 配置项目 | 纯 Nix 项目 |
| `short` | 简单 Nix 项目 | 纯 Nix 项目 |
| `zero` | 从零构建项目 | 纯 Nix 项目 |
| **`project`** | 非纯 Nix 项目 | 项目源码 + nix/ |

## 扩展阅读

- [Nix FHS 手册](../../docs/manual.md)
- [Nix Flakes 文档](https://nixos.wiki/wiki/Flakes)
- [Nixpkgs 指南](https://nixos.org/manual/nixpkgs/stable/)
