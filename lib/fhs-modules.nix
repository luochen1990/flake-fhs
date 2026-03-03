# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Flake FHS module system logic and output generation
#
# ================================================================
# 设计文档: 模块系统
# ================================================================
#
# ## 1. 核心概念
#
# ### 1.1 Guarded Module (受保护模块)
# - 一个目录如果包含 `options.nix` 文件，就被称为 "guarded module"
# - `options.nix` 定义该模块的选项（options）
# - 每个 guarded module 会被展开为两个独立的 nixosModules:
#   - `<modPath>.options` - 仅引入 options.nix
#   - `<modPath>.config` - 引入配置实现
#
# ### 1.2 Unguarded Directory (非受保护目录)
# - 没有 `options.nix` 的目录
# - 其中的 `.nix` 文件会被直接收集
#
# ## 2. default.nix 处理逻辑
#
# default.nix 用于显式控制模块的引入方式，与 options.nix 是独立的机制。
#
# ### 2.1 有 default.nix 的情况
# - 如果 guarded module 目录有 `default.nix`，则 `.config` 模块直接使用它
# - `default.nix` 负责引入该模块的所有配置实现
# - 注意: `default.nix` 不应该引入 `options.nix`（会通过 `.options` 模块单独引入）
#
# ### 2.2 没有 default.nix 的情况 (虚拟 default.nix)
# - 如果 guarded module 目录没有 `default.nix`，系统会创建一个"虚拟 default.nix"
# - 虚拟 default.nix 会递归收集该目录下:
#   - 所有 unguarded 的 `.nix` 文件
#   - 所有有 `default.nix` 的子目录（引入其 default.nix）
# - 但是，如果父目录（或任何祖先）有自己的 `default.nix`，则虚拟 default.nix 为空
#   - 因为父目录的 default.nix 会负责引入所有子目录的内容
#
# ### 2.3 设计意图
# 这个设计允许用户选择两种组织方式:
#
# 方式 A: 手动控制（使用 default.nix）
# ```
# modules/
# └── myapp/
#     ├── options.nix      # 标记为 guarded module
#     └── default.nix      # 显式控制引入哪些文件
# ```
# - default.nix 内容示例:
#   ```nix
#   { ... }: {
#     imports = [ ./config.nix ./services ];
#   }
#   ```
#
# 方式 B: 自动发现（无 default.nix）
# ```
# modules/
# └── myapp/
#     ├── options.nix      # 标记为 guarded module
#     ├── feature1.nix     # 自动被发现
#     ├── feature2.nix     # 自动被发现
#     └── sub/
#         └── feature3.nix # 自动被发现
# ```
# - 系统会自动创建虚拟 default.nix 引入所有 .nix 文件
#
# ## 3. importUnguardedFiles 工具函数
#
# 当在 default.nix 中需要收集文件时，应该使用 `importUnguardedFiles` 而不是 `findFilesRec`:
#
# ```nix
# # bedrock/default.nix
# { tools, ... }: {
#   imports = tools.importUnguardedFiles ".mod.nix" ./.;
# }
# ```
#
# `importUnguardedFiles` 与 `findFilesRec` 的关键区别:
# - `findFilesRec` 会递归穿透所有子目录，可能导致重复引入
# - `importUnguardedFiles` 与 `parentHasDefault` 机制配合:
#   - 遇到有 default.nix 的目录时引入它（让 default.nix 控制引入）
#   - 遇到没有 default.nix 的 guarded module 时，递归处理它的内容
#     （因为 parentHasDefault=true 时，flake-fhs 不会为它生成虚拟 default.nix）
#   - 其他目录递归处理
#
# ## 4. parentHasDefault 传递机制
#
# 当使用 `importUnguardedFiles` 时，系统通过 `parentHasDefault` 参数跟踪祖先状态，
# 确保子 guarded module 的虚拟 default.nix 不会重复引入文件:
#
# ```
# bedrock/                     # 有 options.nix (guarded) + default.nix
# ├── options.nix
# ├── default.nix              # 使用 importUnguardedFiles ".mod.nix"
# ├── prelude.mod.nix          # 由 default.nix 引入
# └── network/                 # 有 options.nix (guarded)，无 default.nix
#     ├── options.nix          # 跳过（不引入 options.nix）
#     ├── core.mod.nix         # 由 bedrock/default.nix 递归引入
#     └── adguard/
#         └── service.mod.nix  # 由 bedrock/default.nix 递归引入
# ```
#
# 在这个例子中:
# - `bedrock/default.nix` 使用 `importUnguardedFiles` 收集 `.mod.nix` 文件
# - `network/` 是 guarded module，没有 default.nix
# - `importUnguardedFiles` 会递归进入 `network/`，收集 `core.mod.nix` 和 `adguard/service.mod.nix`
# - `bedrock/network/` 的虚拟 default.nix 为空（因为 parentHasDefault=true）
# - 结果：每个文件只被引入一次
#
# 在这个例子中:
# - `bedrock/default.nix` 使用 `importUnguardedFiles` 收集 `.mod.nix` 文件
# - `network/` 是 guarded module，`importUnguardedFiles` 会跳过它（不穿透）
# - `bedrock/network/` 的虚拟 default.nix 为空（因为 parentHasDefault=true）
# - `adguard/service.mod.nix` 只被引入一次
#
# ## 5. 输出结构
#
# 对于每个 guarded module，生成:
# - `nixosModules.<modPath>.options` - 选项声明
# - `nixosModules.<modPath>.config` - 配置实现
# - `nixosModules.default` - 引入所有模块的默认入口
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
    listToAttrs
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
  # 
  # 为 guarded module 生成配置模块 (.config)
  # 
  # 引入来源:
  # 1. 如果有 default.nix，则引入它
  # 2. 引入 unguardedConfigPaths（由 mkGuardedTreeNode 收集）
  #    - 如果 parentHasDefault=false 且 hasDefault=false，则包含虚拟 default.nix 的内容
  #    - 否则为空（由祖先或自己的 default.nix 处理）
  #
  mkDefaultModule = config: it: 
    let
      default-dot-nix = it.path + "/default.nix";
      hasDefault = pathExists default-dot-nix;
      defaultImport = if hasDefault then [ default-dot-nix ] else [];
    in {
      imports = defaultImport ++ map (warpModule config it.modPath) it.unguardedConfigPaths;
    };

  # ================================================================
  # Tree Traversal (Guarded)
  # ================================================================

  # mkGuardedTreeNode : { modPath, path, parentHasDefault } -> GuardedTreeNode
  # 
  # GuardedTreeNode 表示一个有 options.nix 的 guarded module
  # 
  # default.nix 处理逻辑:
  # - 如果 guarded module 有 default.nix, 则使用它
  # - 如果 guarded module 没有 default.nix, 则创建一个虚拟的 default.nix
  #   - 虚拟 default.nix 会递归引入该目录下所有 unguarded 的 .nix 文件
  #   - 但是, 如果父目录(或任何祖先)有 default.nix, 则虚拟 default.nix 为空
  #     (因为父目录的 default.nix 会负责引入所有子目录的内容)
  #
  mkGuardedTreeNode =
    {
      modPath,
      path,
      parentHasDefault ? false,
    }:
    let
      # Check if this directory has a default.nix
      default-dot-nix = path + "/default.nix";
      hasDefault = pathExists default-dot-nix;
      
      # 如果父目录有 default.nix, 则不需要收集任何 unguarded 文件
      # 因为父目录的 default.nix 会负责引入所有内容
      # 如果当前目录有 default.nix, 也不需要收集, 因为会直接使用 default.nix
      needCollectUnguarded = !parentHasDefault && !hasDefault;
      
      unguardedConfigPaths = concatLists (
        exploreDir [ path ] (it: rec {
          options-dot-nix = it.path + "/options.nix";
          default-dot-nix = it.path + "/default.nix";
          guarded = pathExists options-dot-nix;
          defaulted = pathExists default-dot-nix;
          # 只有当需要收集时, 才进入子目录
          # 进入非-guarded 且非-defaulted 的目录
          into = needCollectUnguarded && !(guarded || defaulted);
          # 收集非-guarded 的目录(当需要收集时)
          pick = !guarded && needCollectUnguarded;
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
          # 传递给子 guarded module: 如果当前目录或任何祖先有 default.nix
          parentHasDefault = hasDefault || parentHasDefault;
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
          parentHasDefault = false;
        }
      ) rootModulePaths;
    in
    {
      guardedChildrenNodes = concatFor forest (t: t.guardedChildrenNodes);
      unguardedConfigPaths = concatFor forest (t: t.unguardedConfigPaths);
    };

  # ================================================================
  # Output Generation
  # ================================================================

  # Recursively collect all guarded nodes from the tree
  collectAllGuardedNodes = tree:
    tree.guardedChildrenNodes
    ++ concatFor tree.guardedChildrenNodes (it: collectAllGuardedNodes it);

  mkModulesOutput =
    args:
    { moduleTree }:
    let
      allGuardedNodes = collectAllGuardedNodes moduleTree;
    in
    {
      nixosModules =
        listToAttrs (
          concatFor allGuardedNodes (it: [
            {
              name = (concatStringsSep "." it.modPath) + ".options";
              value = mkOptionsModule args it;
            }
            {
              name = (concatStringsSep "." it.modPath) + ".config";
              value = mkDefaultModule args it;
            }
          ])
        )
        // {
          default = {
            imports =
              moduleTree.unguardedConfigPaths
              ++ concatFor allGuardedNodes (it: [
                (mkOptionsModule args it)
                (mkDefaultModule args it)
              ]);
          };
        };
    };

in
{
  inherit
    warpModule
    mkOptionsModule
    mkDefaultModule
    mkGuardedTree
    mkGuardedTreeNode
    mkModulesOutput
    ;
}
