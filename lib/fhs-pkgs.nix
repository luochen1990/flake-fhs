# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Flake FHS scoped package tree logic
#
lib:
let
  inherit (builtins)
    pathExists
    concatStringsSep
    concatMap
    ;

  inherit (lib)
    lsDirs
    lsFiles
    hasSuffix
    forFilter
    removeSuffix
    ;

  # ================================================================
  # Tree Traversal (Scoped)
  # ================================================================

  # loadScopedTree :: Context -> Scope -> Args -> Path -> [String] -> [ { name :: String; value :: Derivation; } ]
  loadScopedTree =
    context: currentScope: currentArgs: path: breadcrumbs:
    let
      # 1. Determine Scope & Args
      scopePath = path + "/scope.nix";
      scopedData = if pathExists scopePath then (import scopePath) context else { };

      # Scope: Inherit (default) or Replace (if provided)
      nextScope = scopedData.scope or currentScope;

      # Args: Inherit & Merge
      nextArgs = currentArgs // (scopedData.args or { });

      # 2. Evaluate Packages

      # 2.1 Directory Package (package.nix)
      pkgPath = path + "/package.nix";
      hasPackage = pathExists pkgPath;
      dirPkg =
        if hasPackage then
          [
            {
              name = concatStringsSep "/" breadcrumbs;
              value = nextScope.callPackage pkgPath nextArgs;
            }
          ]
        else
          [ ];

      # 2.2 File Packages (*.nix)
      filePkgs =
        if hasPackage then
          [ ]
        else
          forFilter (lsFiles path) (
            fname:
            if
              hasSuffix ".nix" fname && fname != "scope.nix" && fname != "default.nix" && fname != "package.nix"
            then
              {
                name = concatStringsSep "/" (breadcrumbs ++ [ (removeSuffix ".nix" fname) ]);
                value = nextScope.callPackage (path + "/${fname}") nextArgs;
              }
            else
              null
          );

      # 3. Recurse
      # Stop recursion if this directory is a package itself (Encapsulation)
      childrenPkgs =
        if hasPackage then
          [ ]
        else
          concatMap (d: loadScopedTree context nextScope nextArgs (path + "/${d}") (breadcrumbs ++ [ d ])) (
            lsDirs path
          );
    in
    dirPkg ++ filePkgs ++ childrenPkgs;

  # loadScopedOutputs :: Config -> Roots -> Subdirs -> SystemContext -> [ { name :: String; value :: Any; } ]
  loadScopedOutputs =
    mkFlakeArgs: roots: subdirsList: sysContext:
    concatMap (
      root:
      let
        validSubdirs = forFilter subdirsList (
          subdir:
          let
            p = root + "/${subdir}";
          in
          if pathExists p then p else null
        );
      in
      concatMap (pkgRoot: loadScopedTree sysContext sysContext.scope { } pkgRoot [ ]) validSubdirs
    ) roots;

in
{
  inherit loadScopedTree loadScopedOutputs;
}
