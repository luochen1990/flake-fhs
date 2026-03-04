# Module System Guide

This document provides detailed guidance on using the flake-fhs module system.

## Overview

The flake-fhs module system automatically discovers and loads NixOS modules from your directory structure. It supports **three mutually exclusive module types**:

1. **Guarded Directory Module** - For optional features with enable/disable control
2. **Traditional Directory Module** - For configuration sets that are always active
3. **Single File Module** - For simple modules

## Module Types in Detail

### 1. Guarded Directory Module

**Identifier**: Directory contains `options.nix` (without `default.nix`)

**Features**:
- Auto-generates `enable` option
- Config files wrapped with `mkIf enable`
- Supports nesting with parent enable checks

**Directory Structure**:
```
modules/
└── my-feature/
    ├── options.nix    # Required: option definitions
    ├── config.nix     # Optional: configuration (wrapped with mkIf)
    └── setup.nix      # Optional: more config files
```

**Example `options.nix`**:
```nix
{ lib, ... }:
{
  options.my-feature = {
    setting1 = lib.mkOption {
      type = lib.types.str;
      default = "default-value";
      description = "A configurable setting";
    };
  };
}
```

**Example `config.nix`**:
```nix
{ config, ... }:
{
  config.my-feature.result = config.my-feature.setting1;
}
```

**Generated Output**:
- `nixosModules.my-feature` - Complete module with options and config
- Enable option: `my-feature.enable` (auto-generated if not defined)

**Usage**:
```nix
# In your NixOS configuration
{ config, ... }:
{
  imports = [ flake.nixosModules.my-feature ];
  
  my-feature = {
    enable = true;  # Must be enabled for config to apply
    setting1 = "custom-value";
  };
}
```

### 2. Traditional Directory Module

**Identifier**: Directory contains `default.nix` (without `options.nix`)

**Features**:
- Direct export, always active
- No enable mechanism
- Does NOT support nesting (subdirs with `default.nix` are ignored)

**Directory Structure**:
```
modules/
└── my-configs/
    └── default.nix   # Required: module definition
```

**Example `default.nix`**:
```nix
{ lib, ... }:
{
  options.my-configs = {
    value1 = lib.mkOption {
      type = lib.types.int;
      default = 42;
    };
  };
  
  config.my-configs = {
    active = true;
  };
}
```

**Generated Output**:
- `nixosModules.my-configs` - Complete module, always applied

**Usage**:
```nix
# In your NixOS configuration
{ config, ... }:
{
  imports = [ flake.nixosModules.my-configs ];
  
  # Config is always applied, no enable needed
  my-configs.value1 = 100;
}
```

### 3. Single File Module

**Identifier**: Standalone `.nix` file in modules directory

**Features**:
- Direct export, always active
- No enable mechanism
- Found recursively in non-guarded, non-traditional directories

**Directory Structure**:
```
modules/
├── utils.nix          # Single file module
└── helpers/
    └── common.nix     # Also a single file module
```

**Example `utils.nix`**:
```nix
{ lib, ... }:
{
  options.utils = {
    enabled = lib.mkEnableOption "utils feature";
  };
  
  config.utils = {
    active = true;
  };
}
```

**Generated Outputs**:
- `nixosModules.utils`
- `nixosModules.helpers.common`

## Nested Guarded Modules

Guarded modules can be nested. Child modules check **ALL** parent enables:

```
modules/
└── network/              # network.enable
    ├── options.nix
    ├── config.nix
    └── services/
        └── web/          # network.enable && network.services.web.enable
            ├── options.nix
            └── config.nix
```

**Generated mkIf conditions**:
- `network/config.nix`: `lib.mkIf config.network.enable { ... }`
- `network/services/web/config.nix`: `lib.mkIf (config.network.enable && config.network.services.web.enable) { ... }`

**Example**:
```nix
{ config, ... }:
{
  imports = [ flake.nixosModules.default ];
  
  network = {
    enable = true;  # Parent must be enabled
    services.web = {
      enable = true;  # Child must also be enabled
      port = 8080;
    };
  };
}
```

## Conflict Detection

**Important**: A directory cannot have both `options.nix` and `default.nix`. This will cause a build error:

```
modules/
└── conflict/
    ├── options.nix   # ❌
    └── default.nix   # ❌ CONFLICT!
```

**Error Message**:
```
Conflict in /path/to/modules/conflict: Cannot have both options.nix and default.nix.
Choose one module type: guarded (options.nix only) or traditional (default.nix only).
```

## Traditional Module Nesting Limitation

Traditional modules **do NOT support nesting**. Subdirectories with `default.nix` are ignored:

```
modules/
└── configs/
    ├── default.nix       # ✅ Recognized: nixosModules.configs
    └── sub/
        └── default.nix   # ❌ NOT recognized (skipped)
```

**Solution**: Use guarded modules for nesting, or create separate top-level modules:
```
modules/
├── configs/              # Traditional module
│   └── default.nix
└── configs-sub/          # Separate traditional module
    └── default.nix
```

## Strict Mode

Options must strictly match the directory structure:

```nix
# modules/foo/options.nix
{ lib, ... }:
{
  options.foo = {  # Must be under 'foo'
    setting = lib.mkOption { ... };
  };
}

# modules/foo/bar/options.nix
{ lib, ... }:
{
  options.foo.bar = {  # Must be under 'foo.bar'
    setting = lib.mkOption { ... };
  };
}
```

## Output Structure

### Individual Module Outputs
Each module generates a single output at `nixosModules.<path>`:

| Directory | Output |
|-----------|--------|
| `modules/myapp/` | `nixosModules.myapp` |
| `modules/services/web/` | `nixosModules.services.web` |
| `modules/utils.nix` | `nixosModules.utils` |

### Default Module
`nixosModules.default` includes ALL modules:
- All guarded modules (with enable guards)
- All traditional modules (always active)
- All single file modules (always active)

```nix
# Import all modules at once
{ ... }:
{
  imports = [ flake.nixosModules.default ];
  
  # Enable guarded modules as needed
  myapp.enable = true;
  services.web.enable = true;
}
```

## Migration from Previous Versions

### From options.nix + default.nix to Guarded Module
**Before**:
```
modules/myapp/
├── options.nix
└── default.nix
```

**After** (rename `default.nix` to `config.nix`):
```
modules/myapp/
├── options.nix
└── config.nix
```

### From Separate .options/.config to Single Output
**Before**:
```nix
imports = [ flake.nixosModules.myapp.options ];
```

**After**:
```nix
imports = [ flake.nixosModules.myapp ];  # Merged output
```

### From optionsMode Configuration
The `optionsMode` configuration has been removed. Now only strict mode is supported:
- Options must match directory structure
- No automatic nesting

### From Nested Traditional Modules
**Before** (sub-modules were recognized):
```
modules/
└── configs/
    ├── default.nix      # nixosModules.configs
    └── sub/
        └── default.nix  # nixosModules.configs.sub
```

**After** (sub-modules are NOT recognized):
- Use guarded modules for nesting
- Or create separate top-level modules
