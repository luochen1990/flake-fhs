# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Flake FHS core implementation
#
flakeFhsLib:
let
  inherit (builtins)
    head
    tail
    elem
    hasAttr
    pathExists
    listToAttrs
    concatLists
    concatStringsSep
    mapAttrs
    ;

  inherit (flakeFhsLib)
    dict
    for
    forFilter
    concatFor
    exploreDir
    lsDirs
    lsFiles
    hasSuffix
    trimPath
    ;

  # Core implementation of mkFlake logic
  mkFlakeCore =
    args:
    let
      inherit (args)
        self
        nixpkgs
        inputs
        lib
        supportedSystems
        nixpkgsConfig
        layout
        systemContext
        ;

      partOf = mapAttrs (
        name: value: x:
        elem x value.subdirs
      ) layout;

      # roots = [Path]

      roots = forFilter layout.roots (
        d:
        let
          p = self.outPath + "/${trimPath d}";
        in
        if pathExists p then p else null
      );

      # system related context
      mkSysContext =
        system:
        let
          pkgs = (
            import nixpkgs {
              inherit system;
              config = nixpkgsConfig;
            }
          );
          preparedLib = flakeFhsLib.prepareLib {
            inherit roots pkgs;
            libSubdirs = layout.lib.subdirs;
            lib = mergedLib;
          };
          mergedLib = flakeFhsLib // preparedLib // lib; # TODO: configurable
          userCtx = systemContext system;
          specialArgs = {
            inherit
              self
              system
              inputs
              ;
            lib = mergedLib;
          }
          // (userCtx.specialArgs or { });

          scope = mergedLib.mkScope pkgs;
        in
        {
          inherit
            self
            system
            pkgs
            specialArgs
            inputs
            scope
            ;
          lib = mergedLib;
        }
        // (removeAttrs userCtx [ "specialArgs" ]);

      # Per-system output builder
      # eachSystem : (SystemContext -> a) -> Dict System a
      eachSystem =
        outputBuilder:
        dict supportedSystems (
          system:
          let
            sysContext = mkSysContext system;
          in
          outputBuilder sysContext
        );

      # Discover module directories
      moduleDirs = concatLists (
        map (
          root:
          forFilter layout.nixosModules.subdirs (
            subdir:
            let
              p = root + "/${subdir}";
            in
            if pathExists p then p else null
          )
        ) roots
      );

      # Collect all modules first to check if there are any
      modulesOutput = flakeFhsLib.mkModulesOutput {
        moduleDirs = moduleDirs;
        suffix = layout.nixosModules.suffix;
      };

      # Shared modules for both NixOS configurations and Colmena
      # Only include modules if there are any
      sharedModules = [
        hostnameModule
      ]
      ++ (
        if builtins.hasAttr "default" modulesOutput.nixosModules then
          [ modulesOutput.nixosModules.default ]
        else
          [ ]
      );

      # Inject hostname by default
      hostnameModule =
        { hostname, lib, ... }:
        {
          networking.hostName = lib.mkDefault hostname;
        };

      # Discover hosts
      validHosts = exploreDir roots (it: rec {
        configuration-dot-nix = it.path + "/configuration.nix";
        marked = pathExists configuration-dot-nix;
        into = it.depth == 0 && partOf.nixosConfigurations it.name;
        pick = it.depth >= 1 && marked;

        # Read system info
        default-dot-nix = it.path + "/default.nix";
        hasDefault = pathExists default-dot-nix;
        info = if hasDefault then import default-dot-nix else { system = "x86_64-linux"; };

        out = {
          name = concatStringsSep "/" (tail it.breadcrumbs');
          path = it.path;
          inherit info;
        };
      });

    in
    {
      # Generate all flake outputs

      # outputs:
      #  pkgs/        # subdirs marked by package.nix
      #  modules/     # unguarded & guarded by options.nix
      #  hosts/       # marked by configuration.nix
      #  shells/      # top-level files & subdirs marked by shell.nix
      #  apps/        # top-level files & subdirs marked by default.nix
      #  utils/       # more/ and other .nix files
      #  checks/      # top-level files & subdirs marked by default.nix
      #  templates/   # top-level subdirs marked by templates.nix

      packages = eachSystem (
        sysContext:
        listToAttrs (flakeFhsLib.loadScopedOutputs args roots layout.packages.subdirs sysContext)
      );

      apps = eachSystem (
        sysContext:
        let
          inherit (flakeFhsLib) inferMainProgram;
          # 1. Collect all packages from 'apps' directories
          rawApps = flakeFhsLib.loadScopedOutputs args roots layout.apps.subdirs sysContext;
        in
        listToAttrs (
          map (app: {
            name = app.name;
            value = {
              type = "app";
              program = "${app.value}/bin/${inferMainProgram app.value}";
            };
          }) rawApps
        )
      );

      checks = eachSystem (
        sysContext: listToAttrs (flakeFhsLib.loadScopedOutputs args roots layout.checks.subdirs sysContext)
      );

      lib = flakeFhsLib.prepareLib {
        inherit roots lib;
        libSubdirs = layout.lib.subdirs;
      };
    }
    // (flakeFhsLib.mkColmenaOutput args {
      inherit validHosts sharedModules mkSysContext;
    })
    // (flakeFhsLib.mkTemplatesOutput args {
      inherit roots;
    })
    // (flakeFhsLib.mkFormatterOutput args {
      inherit eachSystem;
    })
    // modulesOutput
    // (flakeFhsLib.mkConfigurationsOutput args {
      inherit validHosts sharedModules mkSysContext;
    })
    // (flakeFhsLib.mkShellsOutput args {
      inherit roots partOf eachSystem;
    });
in
{
  inherit mkFlakeCore;
}
