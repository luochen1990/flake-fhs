# Chainable utils preparation system
# Provides a hierarchical API for loading utils based on dependency levels

let
  # Helper to load all .nix files from a directory (excluding .fun.nix files)
  loadModulesFromDir = dir:
    let
      dirContent = builtins.readDir dir;
      nixFiles = builtins.filter (name:
        dirContent.${name} == "regular" &&
        builtins.match ".*\\.nix$" name != null &&
        builtins.match ".*\\.fun\\.nix$" name == null
      ) (builtins.attrNames dirContent);
    in
    builtins.listToAttrs (
      builtins.map (name: {
        name = builtins.replaceStrings [".nix"] [""] name;
        value = import (dir + "/${name}");
      }) nixFiles
    );

in
{
  # Main prepareUtils function
  prepareUtils = utilsPath:
    let
      # Load Level 1 modules (builtins only) - no initialization needed
      level1Modules = loadModulesFromDir utilsPath;

      # Check if more directory exists
      morePath = utilsPath + "/more";
      hasMore = builtins.pathExists morePath;

      # Create the Level 1 utils object
      level1Utils = level1Modules // {
        # more() method to access Level 2 with lib args
        more = libArgs:
          let
            # Load Level 2 modules (lib dependent)
            level2Modules = if hasMore then loadModulesFromDir morePath else {};

            # Check if more/more directory exists
            moreMorePath = morePath + "/more";
            hasMoreMore = builtins.pathExists moreMorePath;

            # Initialize Level 2 modules with lib args
            initializedLevel2 = builtins.mapAttrs (name: module:
              if builtins.isFunction module then
                module libArgs
              else
                module
            ) level2Modules;

            # Create the Level 2 utils object
            level2Utils = initializedLevel2 // {
              # more() method to access Level 3 with pkgs args
              more = pkgsArgs:
                let
                  # Load Level 3 modules (lib and pkgs dependent)
                  level3Modules = if hasMoreMore then loadModulesFromDir moreMorePath else {};

                  # Initialize Level 3 modules with both lib and pkgs args
                  initializedLevel3 = builtins.mapAttrs (name: module:
                    if builtins.isFunction module then
                      module (libArgs // pkgsArgs)
                    else
                      module
                  ) level3Modules;

                in
                initializedLevel3;
            };

          in
          level2Utils;
      };
    in
    level1Utils;
}