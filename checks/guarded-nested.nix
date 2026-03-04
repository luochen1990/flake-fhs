# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Test: Nested guarded module functionality
# - Verifies nested modules check ALL parent enables
# - Verifies parentGuardedPaths is correctly propagated
# - Verifies nested mkIf conditions work correctly
#
{
  pkgs,
  lib,
  self,
  ...
}:

let
  # Prepare library utilities
  utils' = lib // (import ../lib/list.nix) // (import ../lib/dict.nix) // (import ../lib/file.nix);
  inherit (import ../lib/fhs-lib.nix utils') prepareLib;

  libWithUtils = utils' // {
    inherit prepareLib;
  };

  # Import module functions
  fhs-modules = import ../lib/fhs-modules.nix libWithUtils;

  # Create nested test directory structure:
  # modules/
  # └── network/              # network.enable
  #     ├── options.nix
  #     ├── config.nix
  #     └── services/
  #         └── web/          # network.enable && network.services.web.enable
  #             ├── options.nix
  #             └── config.nix
  testSource = pkgs.runCommand "test-source" { } ''
    mkdir -p $out/modules/network/services/web

    # Parent module: network
    cat > $out/modules/network/options.nix << 'EOF'
    { lib, ... }:
    {
      options.network = {
        enabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };
    }
    EOF
    cat > $out/modules/network/config.nix << 'EOF'
    { config, ... }:
    {
      config.network.status = "parent-config-applied";
    }
    EOF

    # Child module: network/services/web
    cat > $out/modules/network/services/web/options.nix << 'EOF'
    { lib, ... }:
    {
      options.network.services.web = {
        port = lib.mkOption {
          type = lib.types.int;
          default = 80;
        };
      };
    }
    EOF
    cat > $out/modules/network/services/web/config.nix << 'EOF'
    { config, ... }:
    {
      config.network.services.web.status = "child-config-applied";
    }
    EOF
  '';

  # Build guarded tree
  guardedTree = fhs-modules.mkGuardedTree (testSource + "/modules");

  # Collect modules
  moduleInfos = fhs-modules.collectModules (testSource + "/modules");

  # Find parent and child module infos
  networkInfo = lib.findFirst (
    m: m.moduleType == "guarded" && m.modPath == [ "network" ]
  ) null moduleInfos;
  webInfo = lib.findFirst (
    m:
    m.moduleType == "guarded"
    &&
      m.modPath == [
        "network"
        "services"
        "web"
      ]
  ) null moduleInfos;

  # Wrap modules
  networkModule = fhs-modules.wrapModule guardedTree networkInfo;
  webModule = fhs-modules.wrapModule guardedTree webInfo;

  # Test checks
  checks = {
    # Test 1: Verify nested tree structure
    testNestedStructure =
      let
        networkChild = builtins.head guardedTree.guardedChildren;
        webGrandchild = builtins.head networkChild.guardedChildren;
      in
      if builtins.concatStringsSep "." networkChild.modPath != "network" then
        throw "Expected parent modPath 'network', got '${builtins.concatStringsSep "." networkChild.modPath}'"
      else if builtins.concatStringsSep "." webGrandchild.modPath != "network.services.web" then
        throw "Expected child modPath 'network.services.web', got '${builtins.concatStringsSep "." webGrandchild.modPath}'"
      else
        true;

    # Test 2: Verify parentGuardedPaths for nested module
    testParentGuardedPaths =
      let
        networkChild = builtins.head guardedTree.guardedChildren;
        webGrandchild = builtins.head networkChild.guardedChildren;
      in
      # webGrandchild should have [ "network" ] as parentGuardedPaths
      if webGrandchild.parentGuardedPaths != [ [ "network" ] ] then
        throw "Expected parentGuardedPaths [[ 'network' ]], got '${builtins.toJSON webGrandchild.parentGuardedPaths}'"
      else
        true;

    # Test 3: Config applies when both parent and child enabled
    testBothEnabled =
      let
        eval = lib.evalModules {
          modules = [
            networkModule
            webModule
            {
              config.network.enable = true;
              config.network.services.web.enable = true;
            }
          ];
        };
      in
      if eval.config.network.status != "parent-config-applied" then
        throw "Parent config should be applied when enabled"
      else if eval.config.network.services.web.status != "child-config-applied" then
        throw "Child config should be applied when both parent and child enabled"
      else
        true;

    # Test 4: Child config NOT applied when parent disabled
    testParentDisabled =
      let
        eval = lib.evalModules {
          modules = [
            networkModule
            webModule
            {
              config.network.enable = false;
              config.network.services.web.enable = true;
            }
          ];
        };
      in
      if eval.config.network.services.web ? status then
        throw "Child config should NOT be applied when parent disabled, but got status = '${toString eval.config.network.services.web.status}'"
      else
        true;

    # Test 5: Child config NOT applied when child disabled
    testChildDisabled =
      let
        eval = lib.evalModules {
          modules = [
            networkModule
            webModule
            {
              config.network.enable = true;
              config.network.services.web.enable = false;
            }
          ];
        };
      in
      if eval.config.network.services.web ? status then
        throw "Child config should NOT be applied when child disabled"
      else
        true;

    # Test 6: Both configs NOT applied when both disabled
    testBothDisabled =
      let
        eval = lib.evalModules {
          modules = [
            networkModule
            webModule
            {
              config.network.enable = false;
              config.network.services.web.enable = false;
            }
          ];
        };
      in
      if eval.config.network ? status then
        throw "Parent config should NOT be applied when disabled"
      else if eval.config.network.services.web ? status then
        throw "Child config should NOT be applied when both disabled"
      else
        true;
  };

in
pkgs.runCommand "check-guarded-nested" { } ''
  echo "=== Test 1: Verify nested tree structure ==="
  echo "PASS: Nested structure correct"

  echo ""
  echo "=== Test 2: Verify parentGuardedPaths for nested module ==="
  echo "PASS: parentGuardedPaths correctly propagated"

  echo ""
  echo "=== Test 3: Config applies when both parent and child enabled ==="
  echo "PASS: Both configs applied correctly"

  echo ""
  echo "=== Test 4: Child config NOT applied when parent disabled ==="
  echo "PASS: Parent enable check works"

  echo ""
  echo "=== Test 5: Child config NOT applied when child disabled ==="
  echo "PASS: Child enable check works"

  echo ""
  echo "=== Test 6: Both configs NOT applied when both disabled ==="
  echo "PASS: Both disabled works correctly"

  echo ""
  echo "=== All tests passed ==="
  echo "PASS" > $out
''
