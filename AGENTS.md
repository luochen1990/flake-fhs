# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Flake FHS** (Flake Flake Hierarchy Standard) is a framework for Nix flakes that automatically generates flake outputs from a standardized directory structure, eliminating the need to write repetitive `flake.nix` boilerplate code.

## Core Architecture

### Directory Mapping System

The framework implements an automatic mapping from directory structure to flake outputs:

| Subdirectories (Aliases) | File Pattern | Special Files | Recursive | Generated Output | Nix Command |
|---|---|---|:---:|---|---|
| `packages` (`pkgs`) | `<name>.nix` or `<name>/package.nix` | `scope.nix` | ✅ | `packages.<system>.<name>` | `nix build .#<name>` |
| `nixosModules` (`modules`) | `<name>/...` | `options.nix`, `default.nix` | ✅ | `nixosModules.<name>` | - |
| `nixosConfigurations` (`hosts`, `profiles`) | `<name>/configuration.nix` | - | ✅ | `nixosConfigurations.<name>` | `nixos-rebuild --flake .#<name>` |
| `apps` | `<name>.nix` or `<name>/package.nix` | `scope.nix` | ✅ | `apps.<system>.<name>` | `nix run .#<name>` |
| `devShells` (`shells`) | `<name>.nix` | `default.nix` | ✅ | `devShells.<system>.<name>` | `nix develop .#<name>` |
| `templates` | `<name>/` | `flake.nix` | ❌ | `templates.<name>` | `nix flake init --template <url>#<name>` |
| `lib` (`utils`, `tools`) | `<name>.nix` | - | ✅ | `lib.<name>` | `nix eval .#lib.<name>` |
| `checks` | `<name>.nix` or `<name>/package.nix` | `scope.nix` | ✅ | `checks.<system>.<name>` | `nix flake check .#<name>` |

### Unified Package Model

The framework unifies the handling of `packages`, `apps`, and `checks` under a single **"Scoped Package Tree"** model.

- **Unified Entry**: Supports both single-file (`<name>.nix`) and directory-based (`<name>/package.nix`) definitions.
- **Encapsulation**: If a directory contains `package.nix`, it is treated exclusively as a package definition. Other `.nix` files in that directory are ignored by the automatic scanner (treated as internal helper files).
- **Unified Build**: All components are built using `callPackage`, enjoying automatic dependency injection from `pkgs`.
- **Unified Scoping**: `scope.nix` is supported in all hierarchies (`pkgs`, `apps`, `checks`) to customize dependencies or inject parameters.
- **Explicit Context**: The `scope.nix` function receives the full system context (`pkgs`, `self`, `inputs`, `system`, `lib`) as arguments, allowing users to explicitly inject them into the package scope if desired. Auto-injection is avoided to keep the default scope clean.

### Specific Behaviors

- **Apps**: Automatically converts the built package into an App structure (`{ type="app"; program="..."; }`) by inferring the main program (via `meta.mainProgram` or package name).
- **Checks**: Treated as packages that run tests during build. Access to `self` or `inputs` is available via function arguments.

### Package Scope System (callPackage)

The framework uses `callPackage` to build packages. You can customize the `callPackage` context (scope) via `scope.nix`.

- **File**: `<dir>/scope.nix` (Applies to current directory and subdirectories)
- **Mechanism**:
  - `package.nix` is built using `currentScope.callPackage`.
  - `scope.nix` modifies `currentScope` for its directory (and children).
- **Signature**: `{ pkgs, inputs, ... }: { scope = ...; args = ...; }`
  - **scope** (Optional): The base package set (e.g., `pkgs.pythonPackages`) to use for `callPackage`.
    - If provided: **Replaces** the parent scope.
    - If omitted: **Inherits** the parent scope.
  - **args** (Optional): Attributes to pass as the **second argument** to `callPackage`.
    - These are merged with inherited args from parent directories.
    - Useful for injecting dependencies or configuration into `package.nix`.
- **Granularity**: Works at both directory level (for groups of packages) and package level (sibling of `package.nix`).
- **Usage**: Essential for Python, Perl, and other language-specific package sets, or for injecting parameters into packages.


### Key Components

- **lib/**: Core utility library with Haskell-inspired functional programming patterns
  - `lib/flake-fhs.nix`: Entry point wrapper for `mkFlake`
  - `lib/fhs-core.nix`: Core implementation (`mkFlakeCore`)
  - `lib/fhs-modules.nix`: Module system logic
  - `lib/fhs-pkgs.nix`: Package loading logic
  - `lib/fhs-config.nix`: Configuration options
  - `lib/pkg-tools.nix`: Package helper utilities
  - `lib/dict.nix`, `lib/list.nix`, `lib/file.nix`: Fundamental utilities

 - **templates/**: Project templates for different use cases
   - `std`: Standard template with complete nixos-config and flake outputs 1:1 naming
   - `short`: Short-named template with complete nixos-config
   - `zero`: Minimal template with only flake.nix (directories left for user to create)
   - `project`: Project-embedded template with `./nix` directory (for non-Nix projects)

## Module System Architecture

The framework implements an advanced module loading system:

- **Guarded vs Unguarded Modules**: Directories containing `options.nix` are "guarded" (default disabled), others are "unguarded" (default enabled)
- **Partial Loading**: Implements performance optimization by loading only necessary modules
- **Auto-enable Options**: Automatically generates enable options for guarded modules (if not manually defined)
- **Module Discovery**: Automatically discovers and imports modules based on directory structure
- **Option Nesting**: Automatically nests options under module paths (default behavior, configurable via `optionsMode`) (e.g. `services/web-server/options.nix` -> `options.services.web-server.*`) and auto-generates `enable` option (if missing)

### Module Loading Rules
1. All unguarded directory modules are imported
   - If a directory contains `default.nix`, it is treated as a leaf module (recursion stops) and only `default.nix` is imported
   - Otherwise, all `.nix` files in the directory are imported and subdirectories are recursed
2. All guarded directory `options.nix` files are imported
3. Only enabled guarded modules (enable = true) import their config files

### Options Processing Modes
The `options.nix` processing behavior can be configured via `optionsMode`:
- **strict** (default): No automatic nesting. Enforces that defined options strictly match the directory structure.
- **auto**: Automatically nests options under the directory path (e.g. `foo/options.nix` -> `options.foo.*`) and auto-generates `enable` option.
- **free**: No automatic nesting. Allows arbitrary option definitions.

## Code Quality Standards

### Functional Programming Style
- Use immutable data structures
- Prefer function composition (use tool functions from `lib/` (i.e. `self.lib`) and `builtins` and `lib`)
- Implement higher-order functions for reusable operations and save general ones into `lib/`
- Follow the utility patterns established in `lib/dict.nix` and `lib/list.nix`
- Always add Haskell-style type-signatures for reusable or complex functions

### Nix Conventions
- Follow nixpkgs best practices for package definitions
- Use standard `pkgs/by-name/` structure for packages (`pkgs/<name>/package.nix`)
- Implement proper options and config separation in modules
- Leverage Nix's type system extensively

## Testing Infrastructure

### Template Validation System
- **Core (Nix)**: `checks/template-validation/default.nix` implements a pure-Nix validator that mocks inputs to evaluate all templates against the current library code. It runs automatically via `nix flake check`.
- **Feature Tests**: Standalone checks (e.g., `checks/flake-option.nix`, `checks/scope.nix`) validate specific library features by generating minimal flake structures in the Nix store.
- **Integration (Python)**: `checks/template-validation/validators.py` simulates real-world usage by creating temporary directories, replacing URLs, and running actual Nix commands. Use this for deep integration testing.

### Running Tests
```bash
nix flake check                                  # Standard test (CI friendly)
python checks/template-validation/validators.py  # Manual integration test (Full simulation)
```

## Project Configuration

### lib.mkFlake Usage
Typical flake.nix for users (showing common options):
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-fhs.url = "github:luochen1990/flake-fhs";
  };

  outputs = inputs@{ flake-fhs, ... }:
    flake-fhs.lib.mkFlake { inherit inputs; } {
      # Optional: Explicitly specify systems (flake-parts style)
      systems = [ "x86_64-linux" "x86_64-darwin" ];

      # Optional: Nixpkgs configuration
      nixpkgs.config = {
        allowUnfree = true;
      };

      # Optional: Source roots
      # layout.roots = [ "" "/nix" ];

      # Optional: Enable Colmena integration
      # colmena.enable = true;
    };
}
```

## Colmena Integration

The framework provides native support for [Colmena](https://github.com/zhaofengli/colmena), a deployment tool for NixOS.

### Usage
To enable Colmena support, set `colmena.enable = true` in your `mkFlake` configuration. This will generate a `colmenaHive` output that can be used directly by Colmena.

```nix
outputs = inputs@{ flake-fhs, ... }:
  flake-fhs.lib.mkFlake { inherit inputs; } {
    # ...
    colmena.enable = true;
  };
```

### Features
- Automatically discovers nodes from `nixosConfigurations` directory structure.
- Injects `profileName` into module arguments for each node (accessible via `config.profileName`).
- Sets `deployment.allowLocalDeployment = true` by default.
- Inherits `nixpkgs` revision info from the flake inputs.

### mkFlake Architecture
The `mkFlake` function has been redesigned to use Nix's module system (`lib.evalModules`):
- **First parameter**: Context including `inputs`, `self`, `nixpkgs`, `lib`
- **Second parameter**: Configuration module with type-safe options
- **Core implementation**: `mkFlakeCore` (in `lib/fhs-core.nix`) contains the actual flake generation logic
- **Configuration options**: Defined in `flakeFhsOptions` (in `lib/fhs-config.nix`) with full type checking

## Development Guidelines

### AGENTS.md Maintenance Principles
- **Pattern over Enumeration**: Describe structures using patterns (e.g., `manual-*.md`) instead of exhaustive lists to reduce maintenance burden and noise.
- **Mechanism Focus**: Explain *shared mechanisms* (e.g., "Scoped Package Tree") to guide logical consistency across related components.
- **Conciseness**: Keep instructions high-level and directive. Avoid redundancy with the actual documentation content.

### Core Principles
- **SSOT & DRY**: Central `mkFlake` function handles all output generation
- **Convention Over Configuration**: Standardized directory structure eliminates boilerplate
- **Performance**: Partial loading mechanism for large module sets
- **Type Safety**: Leverages Nix's type system extensively

### File Organization
- Core logic split across `lib/fhs-*.nix` files (`core`, `modules`, `pkgs`, `config`)
- Entry point in `lib/flake-fhs.nix`
- Shared utilities in `lib/` directory
- Templates in `templates/` with embedded documentation
- Comprehensive manual in `docs/manual.md`

### When Modifying Code
1. **Utility Functions**: Reuse existing utilities from `lib/` directory
2. **Module System**: Maintain guarded/unguarded module loading behavior
3. **Template Updates**: Ensure templates work with current `mkFlake` implementation
4. **Testing**: Run template validation after changes that affect flake outputs
5. **Documentation**: Update `docs/manual.md` and related split documents (`manual-*.md`) when features change. Ensure the "Scoped Package Tree" concept is consistent across `pkgs`, `apps`, `checks` documentation.

## Documentation Structure

The manual is modularized (`docs/manual-*.md`) with `docs/manual.md` as the entry point.

- **Core Reference**: `docs/manual-pkgs.md` defines the "Scoped Package Tree" model used by `pkgs`, `apps`, `shells`, and `checks`.
- **Maintenance**:
  - Update `manual.md` for high-level directory mapping changes.
  - Update `manual-pkgs.md` for shared build/scope mechanism changes.
  - Update specific `manual-*.md` files for feature-specific changes.
