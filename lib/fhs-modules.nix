# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Flake FHS module system logic
#
lib:
let
  inherit (builtins)
    head
    tail
    elem
    hasAttr
    concatLists
    concatStringsSep
    pathExists
    removeAttrs
    ;

  inherit (lib)
    lsFiles
    exploreDir
    hasSuffix
    forFilter
    concatFor
    isEmptyFile
    ;

  # ================================================================
  # Module System Helpers
  # ================================================================

  # warpModule :: Config -> [String] -> (Path | Module) -> Module
  warpModule =
    { optionsMode, ... }:
    modPath: module:
    let
      isPath = builtins.isPath module || builtins.isString module;
      file = if isPath then module else null;
      raw = if isPath then if isEmptyFile module then { } else import module else module;

      # Check logic for Strict mode
      checkStrict =
        opts: path:
        if opts == { } || path == [ ] then
          true
        else
          let
            h = head path;
          in
          if hasAttr h opts && removeAttrs opts [ h ] == { } then
            checkStrict opts.${h} (tail path)
          else
            false;

      # Core logic to transform module content
      transform =
        content:
        {
          config,
          lib,
          ...
        }:
        let
          opts = content.options or { };

          # 1. Validation
          _ =
            if optionsMode == "strict" && !checkStrict opts modPath then
              throw "Strict mode violation: options in ${toString file} must strictly follow the directory structure ${concatStringsSep "." modPath}"
            else
              null;

          # 2. Nesting
          nestedOpts = if optionsMode == "auto" && opts != { } then lib.setAttrByPath modPath opts else opts;

          # 3. Enable Option
          enablePath = modPath ++ [ "enable" ];
          finalOpts =
            if
              file != null
              && baseNameOf (toString file) == "options.nix"
              && !lib.hasAttrByPath enablePath nestedOpts
            then
              lib.recursiveUpdate nestedOpts (
                lib.setAttrByPath modPath {
                  enable = lib.mkEnableOption (concatStringsSep "." modPath);
                }
              )
            else
              nestedOpts;

          # 4. Config
          explicitConfig = content.config or { };
          implicitConfig = removeAttrs content [
            "imports"
            "options"
            "config"
            "_file"
            "meta"
            "disabledModules"
            "__functor"
            "__functionArgs"
          ];
          mergedConfig = explicitConfig // implicitConfig;
        in
        {
          imports = content.imports or [ ];
          options = finalOpts;
          config = lib.mkIf (lib.attrsets.getAttrFromPath enablePath config) mergedConfig;
        };

      # Wrap raw module into a functor
      functor =
        if builtins.isFunction raw then
          {
            __functor = self: args: transform (raw args) args;
            __functionArgs = builtins.functionArgs raw;
          }
        else
          {
            __functor = self: args: transform raw args;
          };
    in
    if file != null then
      {
        _file = file;
        imports = [ functor ];
      }
    else
      functor;

  # mkOptionsModule : Config -> GuardedTreeNode -> Module
  mkOptionsModule =
    config: it:
    let
      modPath = it.modPath;
      options-dot-nix = it.path + "/options.nix";
    in
    {
      imports = [
        (warpModule config modPath options-dot-nix)
      ];
    };

  # mkDefaultModule : Config -> GuardedTreeNode -> Module
  mkDefaultModule = config: it: {
    imports = map (warpModule config it.modPath) it.unguardedConfigPaths;
  };

  # ================================================================
  # Tree Traversal (Guarded)
  # ================================================================

  mkGuardedTreeNode =
    {
      modPath,
      path,
    }:
    let
      unguardedConfigPaths = concatLists (
        exploreDir [ path ] (it: rec {
          options-dot-nix = it.path + "/options.nix";
          default-dot-nix = it.path + "/default.nix";
          guarded = pathExists options-dot-nix;
          defaulted = pathExists default-dot-nix;
          into = !(guarded || defaulted);
          pick = !guarded;
          out =
            if defaulted then
              [ default-dot-nix ]
            else
              forFilter (lsFiles it.path) (
                fname: if hasSuffix ".nix" fname then (it.path + "/${fname}") else null
              );
        })
      );

      guardedChildrenNodes = exploreDir [ path ] (it: rec {
        options-dot-nix = it.path + "/options.nix";
        guarded = pathExists options-dot-nix;
        into = !guarded;
        pick = guarded;
        out = mkGuardedTreeNode {
          modPath = it.breadcrumbs';
          path = it.path;
        };
      });
    in
    {
      inherit
        modPath
        path
        guardedChildrenNodes
        unguardedConfigPaths
        ;
    };

  mkGuardedTree =
    config: rootModulePaths:
    let
      forest = map (
        path:
        mkGuardedTreeNode {
          inherit path;
          modPath = [ ];
        }
      ) rootModulePaths;
    in
    {
      guardedChildrenNodes = concatFor forest (t: t.guardedChildrenNodes);
      unguardedConfigPaths = concatFor forest (t: t.unguardedConfigPaths);
    };

in
{
  inherit
    warpModule
    mkOptionsModule
    mkDefaultModule
    mkGuardedTree
    mkGuardedTreeNode
    ;
}
