# Flake FHS

**Flake FHS** (Flake Filesystem Hierarchy Standard) is a Nix Flake framework that automatically generates flake outputs based on a standardized directory structure.

## A Directory Tree is a Flake

Just drop your files into the designated directories, and the corresponding Flake outputs are automatically generated:

*   `pkgs/` -> `packages`
*   `hosts/` -> `nixosConfigurations`
*   `modules/` -> `nixosModules`
*   `apps/` -> `apps`
*   `shells/` -> `devShells`
*   `checks/` -> `checks`
*   `lib/` -> `lib`

## Why Flake FHS?

*   **Zero Boilerplate**: No more manually maintaining complex and repetitive `flake.nix` code.
*   **Predictable Structure**: Standardized directory hierarchy makes any project architecture instantly understandable.
*   **Unified Paradigm**: All outputs share the same consistent dependency injection mechanism.
*   **Progressive Adoption**: Can be used alongside your existing Flake configuration for a smooth transition.

## Quick Start

```bash
# Initialize a new project with the short-name template
nix flake init --template github:luochen1990/flake-fhs
```

## Documentation

Visit the official documentation site: **[flake-fhs.lambda.lc](https://flake-fhs.lambda.lc)**

---
MIT License | Copyright © 2025 Luochen
