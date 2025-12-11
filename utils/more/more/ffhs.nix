# Flake FHS core implementation
# mkFlake function that auto-generates flake outputs from directory structure

{ lib, pkgs }:

let
  # Import utils preparation system
  utilsSystem = import ../../utils.nix;

  # Import basic utils that don't require external dependencies
  basicUtils = utilsSystem.prepareUtils ../../...;

  inherit (basicUtils.dict)
    unionFor
    dict
    ;

  inherit (basicUtils.list)
    for
    concatMap
    ;

  # System context helper
  systemContext = selfArg: system: rec {
    inherit system;
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    tools = utilsSystem.prepareUtils ../../..
           .more { inherit lib; }
           .more { inherit pkgs; };
    specialArgs = {
      self = selfArg;
      inherit
        system
        pkgs
        inputs
        tools
        ;
    };
  };

  # Helper to process multiple root directories
  eachSystem' = supportedSystems: selfArg: f: dict supportedSystems (system: f (systemContext selfArg system));
  eachSystem = eachSystem' (lib.systems.flakeExposed or [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ]);

  # Discover components from multiple root directories
  discoverComponents = fileUtils: roots: componentType:
    unionFor roots (root:
      let
        componentPath = root + "/${componentType}";
      in
      if builtins.pathExists componentPath then
        for (fileUtils.lsDirs componentPath) (name: {
          inherit name root;
          path = componentPath + "/${name}";
        })
      else
        []
    );

in
rec {
  # Main mkFlake function
  mkFlake = args:
    let
      roots = args.root or [ ./. ];
      supportedSystems = args.supportedSystems or (lib.systems.flakeExposed or [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ]);
      nixpkgsConfig = args.nixpkgsConfig or { allowUnfree = true; };
      inputs = args.inputs or {};

      # Override systemContext with custom config
      systemContext' = selfArg: system: rec {
        inherit system;
        pkgs = import nixpkgs {
          inherit system;
          config = nixpkgsConfig;
        };
        tools = utilsSystem.prepareUtils ../../..
           .more { inherit lib; }
           .more { inherit pkgs; };
        specialArgs = {
          self = selfArg;
          inherit
            system
            pkgs
            inputs
            tools
            roots
            ;
        };
      };

      eachSystem' = supportedSystems: selfArg: f: dict supportedSystems (system: f (systemContext' selfArg system));
      eachSystem = eachSystem' supportedSystems args.self;

      # Updated component discovery that respects multiple roots
      discoverComponents' = componentType:
        let
          fileUtils = (utilsSystem.prepareUtils ../../..
               .more { inherit lib; }).file;
          # Collect components from all roots as a flat list
          allComponents =
            concatMap (root:
              let
                componentPath = root + "/${componentType}";
              in
              if builtins.pathExists componentPath then
                for (fileUtils.lsDirs componentPath) (name: {
                  inherit name root;
                  path = componentPath + "/${name}";
                })
              else
              []
            ) roots;
        in
        allComponents;

      # Package discovery with optional default.nix control
      buildPackages' = context:
        let
          components = discoverComponents' "pkgs";
          # Check if any pkgs/default.nix exists in roots
          hasDefault = builtins.any (root: builtins.pathExists (root + "/pkgs/default.nix")) roots;
        in
        if hasDefault then
          # Use default.nix to control package visibility
          let
            defaultPkgs = concatMap (root:
              let
                defaultPath = root + "/pkgs/default.nix";
              in
              if builtins.pathExists defaultPath then
                let result = import defaultPath context;
                in if builtins.isAttrs result then [result] else []
              else []
            ) roots;
          in
          # Merge all package sets from default.nix files
          builtins.foldl' (acc: pkgs: acc // pkgs) {} defaultPkgs
        else
          # Auto-discover all packages
          dict components (name:
            { path, ... }:
            {
              "${name}" = context.pkgs.callPackage (path + "/package.nix") { };
            }
          );

    in
    {
      # Generate all flake outputs
      packages = eachSystem (
        context:
        buildPackages' context
      );

      devShells = eachSystem (
        context:
        let
          components = discoverComponents' "shells";
        in
        let
            componentList = components;
          in
          builtins.foldl' (acc: comp: acc // {
            "${comp.name}" = import comp.path context;
          }) {} componentList
      );

      apps = eachSystem (
        context:
        let
          components = discoverComponents' "apps";
        in
        let
            componentList = components;
          in
          builtins.foldl' (acc: comp: acc // {
            "${comp.name}" = import comp.path context;
          }) {} componentList
      );

      nixosModules =
        let
          components = discoverComponents' "modules";
        in
        let
            componentList = components;
          in
          builtins.foldl' (acc: comp: acc // {
            "${comp.name}" = import comp.path;
          }) {} componentList
        // {
          default =
            let
              context = systemContext' args.self "x86_64-linux";
            in
            unionFor components (
              { name, path, ... }:
              import path
            );
        };

      nixosConfigurations =
        let
          components = discoverComponents' "profiles";
          context = systemContext' args.self "x86_64-linux";
          modulesList = let
            moduleComponents = discoverComponents' "modules";
          in
          builtins.foldl' (acc: comp: acc ++ [import comp.path]) [] moduleComponents;
        in
        let
            profileList = components;
          in
          builtins.foldl' (acc: comp: acc // {
            "${comp.name}" = nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = context.specialArgs // { name = comp.name; };
              modules = [ (comp.path + "/configuration.nix") ] ++ modulesList;
            };
          }) {} profileList;

      checks = eachSystem (
        context:
        let
          components = discoverComponents' "checks";
        in
        let
            componentList = components;
          in
          builtins.foldl' (acc: comp: acc // {
            "${comp.name}" = import comp.path context;
          }) {} componentList
      );

      lib =
        let
          context = systemContext' args.self "x86_64-linux";
          # Filter out system utils directory to avoid conflicts
          userUtilsComponents = builtins.filter (comp: comp.name != "utils") (discoverComponents' "utils");
        in
        builtins.foldl' (acc: comp: acc // {
          "${comp.name}" = import comp.path context;
        }) {} userUtilsComponents;

      templates = {
        simple-project = {
          path = ./templates/simple-project;
          description = "Simple project using Flake FHS";
        };
        package-module = {
          path = ./templates/package-module;
          description = "NixOS module package using Flake FHS";
        };
        full-featured = {
          path = ./templates/full-featured;
          description = "Full-featured project using Flake FHS";
        };
      };

      # Auto-generated overlay for packages
      overlays.default = final: prev:
        let
          utilsSystem = import ../../utils.nix;
          overlayUtils = utilsSystem.prepareUtils ../../..
                       .more { lib = final.lib; }
                       .more { pkgs = final; };
          context = { pkgs = final; inherit (final) lib; tools = overlayUtils; };
        in
        buildPackages' context;

      # Formatter
      formatter = eachSystem (
        { system, pkgs, ... }:
        pkgs.nixfmt-tree or pkgs.nixfmt
      );
    };

  # Helper functions
  inherit discoverComponents systemContext eachSystem;
}