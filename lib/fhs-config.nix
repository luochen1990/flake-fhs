# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Flake FHS configuration schemas
#
lib:
let
  # ================================================================
  # Configuration Schema
  # ================================================================
  defaultLayout = {
    roots = {
      subdirs = [
        ""
        "/nix"
      ];
    };
    packages = {
      subdirs = [
        "pkgs"
        "packages"
      ];
    };
    nixosModules = {
      subdirs = [
        "modules"
        "nixosModules"
      ];
    };
    nixosConfigurations = {
      subdirs = [
        "hosts"
        "profiles"
        "nixosConfigurations"
      ];
    };
    devShells = {
      subdirs = [
        "shells"
        "devShells"
      ];
    };
    apps = {
      subdirs = [ "apps" ];
    };
    lib = {
      subdirs = [
        "lib"
        "tools"
        "utils"
      ];
    };
    checks = {
      subdirs = [ "checks" ];
    };
    templates = {
      subdirs = [ "templates" ];
    };
  };

  # Configuration Module Schema
  flakeFhsOptions =
    { lib, ... }:
    let
      mkLayoutEntry =
        description: default:
        lib.mkOption {
          inherit description;
          inherit default;
          type =
            lib.types.coercedTo (lib.types.listOf (lib.types.either lib.types.str lib.types.path))
              (l: { subdirs = l; })
              (
                lib.types.submodule {
                  options.subdirs = lib.mkOption {
                    type = lib.types.listOf (lib.types.either lib.types.str lib.types.path);
                    description = "List of subdirectories or paths";
                    default = [ ];
                  };
                }
              );
        };
    in
    {
      options = {
        systems = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = lib.systems.flakeExposed;
          description = "List of supported systems";
        };

        optionsMode = lib.mkOption {
          type = lib.types.enum [
            "auto"
            "strict"
            "free"
          ];
          default = "strict";
          description = "Mode for handling options.nix files: 'auto' (nest options under module path), 'strict' (check options match module path), 'free' (no restrictions)";
        };

        nixpkgs.config = lib.mkOption {
          type = lib.types.attrs;
          default = {
            allowUnfree = true;
          };
          description = "Nixpkgs configuration";
        };

        layout = lib.mkOption {
          type = lib.types.submodule {
            freeformType = lib.types.attrs;
            options = {
              roots = mkLayoutEntry "Roots directories" defaultLayout.roots;
              packages = mkLayoutEntry "Packages directories" defaultLayout.packages;
              nixosModules = mkLayoutEntry "NixOS modules directories" defaultLayout.nixosModules;
              nixosConfigurations = mkLayoutEntry "NixOS configurations directories" defaultLayout.nixosConfigurations;
              devShells = mkLayoutEntry "DevShells directories" defaultLayout.devShells;
              apps = mkLayoutEntry "Apps directories" defaultLayout.apps;
              lib = mkLayoutEntry "Lib directories" defaultLayout.lib;
              checks = mkLayoutEntry "Checks directories" defaultLayout.checks;
              templates = mkLayoutEntry "Templates directories" defaultLayout.templates;
            };
          };
          default = { };
          description = "Directory layout configuration";
        };

        colmena = lib.mkOption {
          type = lib.types.submodule {
            options = {
              enable = lib.mkEnableOption "colmena integration";
            };
          };
          default = { };
          description = "Colmena configuration";
        };

        flake = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra flake outputs to merge with FHS outputs";
        };

        systemContext = lib.mkOption {
          description = "Context generator dependent on system";
          default = _: { };
          type = lib.mkOptionType {
            name = "systemContext";
            description = "function system -> attrs";
            check = lib.isFunction;
            merge =
              loc: defs: system:
              lib.foldl' (acc: def: lib.recursiveUpdate acc (def.value system)) { } defs;
          };
        };
      };
    };
in
{
  inherit defaultLayout flakeFhsOptions;
}
