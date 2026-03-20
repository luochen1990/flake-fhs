# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Flake FHS devShells output implementation
# - Loads user-defined shells from shells/ directory
# - Auto-generates default devShell from project derivations (if not user-defined)
#
flakeFhsLib:
let
  inherit (builtins)
    listToAttrs
    concatLists
    concatStringsSep
    tail
    pathExists
    ;

  inherit (flakeFhsLib)
    exploreDir
    forFilter
    lsFiles
    hasSuffix
    removeSuffix
    ;
in
{
  mkShellsOutput =
    args:
    {
      roots,
      partOf,
      eachSystem,
      allProjectDrvs,
      formatter,
    }:
    let
      # Load user-defined shells from directory
      userShells =
        evalContext:
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
                        name = removeSuffix ".nix" fname;
                        value = import (it.path + "/${fname}") evalContext;
                      }
                    else
                      null
                  )
                else if isShellsSubDir && pathExists (it.path + "/default.nix") then
                  # Case 2: shells/<name>/default.nix -> devShells.<name>
                  [
                    {
                      name = concatStringsSep "/" (tail it.breadcrumbs');
                      value = import (it.path + "/default.nix") evalContext;
                    }
                  ]
                else
                  [ ];

              pick = out != [ ];
            })
          )
        );

    in
    {
      devShells = eachSystem (
        evalContext:
        {
          default = evalContext.pkgs.mkShell {
            inputsFrom = allProjectDrvs evalContext;
            packages = [ formatter.${evalContext.system} ];
          };
        }
        // userShells evalContext
      );
    };
}
