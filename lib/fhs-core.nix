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
        optionsMode
        colmena
        layout
        systemContext
        ;

      partOf = mapAttrs (
        name: value: x:
        elem x (value.subdirs)
      ) layout;

      # roots = [Path]

      roots = forFilter (layout.roots.subdirs or [ ]) (
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

      moduleTree = flakeFhsLib.mkGuardedTree args (
        concatFor roots (
          root:
          forFilter layout.nixosModules.subdirs (
            subdir:
            let
              p = root + "/${subdir}";
            in
            if pathExists p then p else null
          )
        )
      );

      # Shared modules for both NixOS configurations and Colmena
      sharedModules =
        moduleTree.unguardedConfigPaths
        ++ concatFor moduleTree.guardedChildrenNodes (it: [
          (flakeFhsLib.mkOptionsModule args it)
          (flakeFhsLib.mkDefaultModule args it)
        ])
        ++ [
          hostnameModule
        ];

      # Inject hostname by default
      hostnameModule =
        { hostname, lib, ... }:
        {
          networking.hostName = lib.mkDefault hostname;
        };

      # This module makes colmena & nixosConfigurations produce exactly the same toplevel outPath
      colmenaShimModule = {
        # Fix VersionName diff between colmena & nixosConfigurations
        system.nixos.revision = nixpkgs.rev or nixpkgs.dirtyRev or null;
        system.nixos.versionSuffix =
          if nixpkgs ? lastModifiedDate && nixpkgs ? shortRev then
            ".${builtins.substring 0 8 nixpkgs.lastModifiedDate}.${nixpkgs.shortRev}"
          else
            "";
        # Fix NIX_PATH diff between colmena & nixosConfigurations
        nixpkgs.flake.source = nixpkgs.outPath;
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

      devShells = eachSystem (
        sysContext:
        listToAttrs (
          concatLists (
            exploreDir roots (it: rec {
              isShellsRoot = it.depth == 0 && partOf.devShells it.name;
              isShellsSubDir = it.depth >= 1;

              into = isShellsRoot || isShellsSubDir;

              out =
                if isShellsRoot then
                  # Case 1: shells/*.nix -> devShells.*
                  forFilter (lsFiles it.path) (
                    fname:
                    if hasSuffix ".nix" fname then
                      {
                        name = flakeFhsLib.removeSuffix ".nix" fname;
                        value = import (it.path + "/${fname}") sysContext;
                      }
                    else
                      null
                  )
                else if isShellsSubDir && pathExists (it.path + "/default.nix") then
                  # Case 2: shells/<name>/default.nix -> devShells.<name>
                  [
                    {
                      name = concatStringsSep "/" (tail it.breadcrumbs');
                      value = import (it.path + "/default.nix") sysContext;
                    }
                  ]
                else
                  [ ];

              pick = out != [ ];
            })
          )
        )
      );

      nixosModules =
        listToAttrs (
          concatFor moduleTree.guardedChildrenNodes (it: [
            {
              name = (concatStringsSep "." it.modPath) + ".options";
              value = flakeFhsLib.mkOptionsModule args it;
            }
            {
              name = (concatStringsSep "." it.modPath) + ".config";
              value = flakeFhsLib.mkDefaultModule args it;
            }
          ])
        )
        // {
          default = {
            imports = moduleTree.unguardedConfigPaths;
          };
        };

      nixosConfigurations = listToAttrs (
        map (
          host:
          let
            sysContext = mkSysContext host.info.system;
            modules = sharedModules ++ [
              (host.path + "/configuration.nix")
            ];
          in
          {
            name = host.name;
            value = lib.nixosSystem {
              inherit (sysContext)
                system
                lib
                ;
              specialArgs = sysContext.specialArgs // {
                hostname = host.name;
              };
              modules = modules ++ [
                { nixpkgs.pkgs = sysContext.pkgs; }
              ];
            };
          }
        ) validHosts
      );

      checks = eachSystem (
        sysContext: listToAttrs (flakeFhsLib.loadScopedOutputs args roots layout.checks.subdirs sysContext)
      );

      lib = flakeFhsLib.prepareLib {
        inherit roots lib;
        libSubdirs = layout.lib.subdirs;
      };

      templates =
        let
          readTemplatesFromRoot =
            root:
            let
              templatePath = root + "/templates";
            in
            if pathExists templatePath then
              for (lsDirs templatePath) (
                name:
                let
                  fullPath = templatePath + "/${name}";
                  flakePath = fullPath + "/flake.nix";
                  hasFlake = pathExists flakePath;
                  description =
                    if hasFlake then (import flakePath).description or "Template: ${name}" else "Template: ${name}";
                in
                {
                  inherit name;
                  value = {
                    path = fullPath;
                    inherit description;
                  };
                }
              )
            else
              [ ];

          allTemplateLists = map readTemplatesFromRoot roots;
          allTemplates = concatLists allTemplateLists;
        in
        builtins.listToAttrs allTemplates;

      # Formatter
      formatter = eachSystem (
        { pkgs, ... }:
        let
          treefmtNix = self.outPath + "/treefmt.nix";
          treefmtToml = self.outPath + "/treefmt.toml";
        in
        if pathExists treefmtNix then
          if (inputs ? treefmt-nix) then
            (inputs.treefmt-nix.lib.evalModule pkgs treefmtNix).config.build.wrapper
          else
            #NOTE: the treefmt.nix format is different here
            #DOC: https://nixos.org/manual/nixpkgs/stable/#opt-treefmt-settings
            pkgs.treefmt.withConfig { settings = import treefmtNix; }
        else if pathExists treefmtToml then
          pkgs.treefmt.withConfig { configFile = treefmtToml; }
        else
          pkgs.treefmt
      );
    }
    // (
      if colmena.enable then
        {
          colmenaHive = inputs.colmena.lib.makeHive (
            {
              meta = {
                nixpkgs = (mkSysContext (head supportedSystems)).pkgs;
                nodeNixpkgs = listToAttrs (
                  map (host: {
                    name = host.name;
                    value = (mkSysContext host.info.system).pkgs;
                  }) validHosts
                );
                nodeSpecialArgs = listToAttrs (
                  map (
                    host:
                    let
                      sysContext = mkSysContext host.info.system;
                    in
                    {
                      name = host.name;
                      value = sysContext.specialArgs // {
                        hostname = host.name;
                      };
                    }
                  ) validHosts
                );
              };
            }
            // listToAttrs (
              map (host: {
                name = host.name;
                value = {
                  deployment.allowLocalDeployment = true;
                  imports = sharedModules ++ [
                    (host.path + "/configuration.nix")
                    colmenaShimModule
                  ];
                };
              }) validHosts
            )
          );
        }
      else
        { }
    );
in
{
  inherit mkFlakeCore;
}
