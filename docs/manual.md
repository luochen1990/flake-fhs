Flake FHS 使用手册
==================

## 映射表

**文件路径 → flake output → Nix 子命令**

| 文件路径  | 生成的 flake output  |  Nix 子命令         |
| ------------- | ------------------ | ------------------------ |
| `pkgs/<name>/package.nix`      | `packages.<system>.<name>`                   | `nix build .#<name>`               |
| `modules/<name>/options.nix`   | `nixosModules.<name>`  |  |
| `profiles/<name>/configuration.nix`   | `nixosConfigurations.<name>`  | `nixos-rebuild --flake .#<name>`    |
| `apps/<name>/default.nix`      | `apps.<system>.<name>`                       | `nix run .#<name>`                 |
| `shells/<name>.nix` | `devShells.<system>.<name>`                  | `nix develop .#<name>`             |
| `templates/<name>/`    | `templates.<name>`                           | `nix flake init --template <name>` |
| `lib/<name>.nix`       | `lib.<name>`                                 | `nix eval .#lib.<name>`            |
| `checks/<name>.nix`       | `checks.<system>.<name>`                                 | `nix flake check .#<name>`            |

特点：

* 所有 `<name>` 来自文件/目录名（无需声明）
* 所有 `<system>` 根据配置选项生成，在执行命令时默认为当前系统平台
* 所有 mapping 由 Flake FHS 自动完成

## pkgs/

`pkgs/<name>/` 子目录下的文件结构与 **nixpkgs** 项目的 `pkgs/by-name/xx/<name>/` 子目录下的结构保持一致，入口文件都是 `package.nix`

### 隐藏部分包的可见性

有时候，我们为了打包 a 会递归地打包它所依赖的 b，c，d 包，但也许我们并不希望对外提供 b, c, d，这时我们会希望能控制 pkgs/ 目录下的包对外的可见性，在这种情况下，可以提供一个 `pkgs/default.nix` 文件，如果存在这个文件，则 Flake FHS 会优先使用该文件导出的包作为 flake outputs 中的 packages，而当 `pkgs/default.nix` 文件不存在时，Flake FHS 会认为 pkgs/ 目录下的所有包都是需要导出为 flake outputs 的

## modules/

在 nixpkgs 中，modules/ 目录下的模块是由 module-list.nix 手动引入的，但是在 Flake FHS 中，我们会规定 modules/ 目录的结构，并依据此规范自动引入所有模块代码.

`modules/` 子目录下的文件结构与 **nixpkgs** 项目的 `modules/by-name/xx/<name>/` 子目录下的结构保持一致，入口文件都是 `package.nix`

## profiles/

在 profiles 目录中，基本上是一个子目录对应 nixosConfigurations 中的一项，除了 `profiles/shared/` 这个特殊目录，它用来存放在多个 profiles 之间共用的配置片段。

## apps/

在 apps 目录中，一个子目录对应 flake-outputs.apps 中的一项，子目录的结构为:

apps/
 - hello/
    - default.nix
    - hello.py

## shells/

在 shells/ 目录中，一个子目录对应 flake-outputs.devShells 中的一项，子目录的结构为:

shells/
 - default/
    - default.nix

## templates/

在 templates/ 目录中，一个子目录对应 flake-outputs.templates 中的一项，子目录的结构为:

...

## lib/

## checks/

在 checks/ 目录中，一个子目录对应 flake-outputs.checks 中的一项，子目录的结构为:

...

## overlays

flake-outputs.overlays 将根据 pkgs/ 自动生成

