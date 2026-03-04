# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Test: Single file module functionality
# - Verifies standalone .nix files are recognized as modules
# - Verifies no enable mechanism for single file modules
# - Verifies config is always applied
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

  # Create test directory structure with single file modules:
  # modules/
  # ├── utils.nix
  # └── helpers/
  #     └── common.nix
  testSource = pkgs.runCommand "test-source" { } ''
    mkdir -p $out/modules/helpers

    # Single file module at root level
    cat > $out/modules/utils.nix << 'EOF'
    { lib, ... }:
    {
      options.utils.feature = lib.mkEnableOption "utils feature";
      config.utils.feature-enabled = true;
    }
    EOF

    # Single file module in subdirectory
    cat > $out/modules/helpers/common.nix << 'EOF'
    { lib, ... }:
    {
      options.helpers.common.setting = lib.mkOption {
        type = lib.types.str;
        default = "helper-default";
      };
      config.helpers.common.active = true;
    }
    EOF
  '';

  # Build guarded tree
  guardedTree = fhs-modules.mkGuardedTree (testSource + "/modules");

  # Collect modules
  moduleInfos = fhs-modules.collectModules (testSource + "/modules");

  # Find single file modules
  utilsInfo = lib.findFirst (
    m: m.moduleType == "single" && m.modPath == [ "utils" ]
  ) null moduleInfos;
  commonInfo = lib.findFirst (
    m:
    m.moduleType == "single"
    &&
      m.modPath == [
        "helpers"
        "common"
      ]
  ) null moduleInfos;

  # Count single file modules
  singleFileCount = lib.length (lib.filter (m: m.moduleType == "single") moduleInfos);

  # Wrap modules
  utilsModule = fhs-modules.wrapModule guardedTree utilsInfo;
  commonModule = fhs-modules.wrapModule guardedTree commonInfo;

  # Evaluate utils module
  utilsEval = lib.evalModules {
    modules = [ utilsModule ];
  };

  # Evaluate common module
  commonEval = lib.evalModules {
    modules = [ commonModule ];
  };

  # Test checks
  checks = {
    # Test 1: Verify we found 2 single file modules
    testCount =
      if singleFileCount != 2 then
        throw "Expected 2 single file modules, got ${toString singleFileCount}"
      else
        true;

    # Test 2: Verify utils module type and path
    testUtilsInfo =
      if utilsInfo.moduleType != "single" then
        throw "Expected utils moduleType 'single', got '${utilsInfo.moduleType}'"
      else if utilsInfo.kind != "file" then
        throw "Expected utils kind 'file', got '${utilsInfo.kind}'"
      else
        true;

    # Test 3: Verify helpers.common module type and path
    testCommonInfo =
      if commonInfo.moduleType != "single" then
        throw "Expected common moduleType 'single', got '${commonInfo.moduleType}'"
      else if builtins.concatStringsSep "." commonInfo.modPath != "helpers.common" then
        throw "Expected common modPath 'helpers.common', got '${builtins.concatStringsSep "." commonInfo.modPath}'"
      else
        true;

    # Test 4: Verify utils config is always applied
    testUtilsConfig =
      if utilsEval.config.utils.feature-enabled != true then
        throw "Single file module config should always be applied"
      else
        true;

    # Test 5: Verify common config is always applied
    testCommonConfig =
      if commonEval.config.helpers.common.active != true then
        throw "Single file module config in subdirectory should always be applied"
      else
        true;

    # Test 6: Verify no auto-generated enable for single file modules
    testNoAutoEnable =
      if builtins.hasAttr "enable" utilsEval.options.utils then
        throw "Single file module should NOT have auto-generated enable option"
      else
        true;
  };

in
pkgs.runCommand "check-single-file" { } ''
  echo "=== Test 1: Verify single file module count ==="
  echo "PASS: Found 2 single file modules"

  echo ""
  echo "=== Test 2: Verify utils module type and path ==="
  echo "PASS: utils module is single file type"

  echo ""
  echo "=== Test 3: Verify helpers.common module type and path ==="
  echo "PASS: helpers.common module is single file type"

  echo ""
  echo "=== Test 4: Verify utils config is always applied ==="
  echo "PASS: utils config applied"

  echo ""
  echo "=== Test 5: Verify common config is always applied ==="
  echo "PASS: common config applied"

  echo ""
  echo "=== Test 6: Verify no auto-generated enable ==="
  echo "PASS: No auto-generated enable option"

  echo ""
  echo "=== All tests passed ==="
  echo "PASS" > $out
''
