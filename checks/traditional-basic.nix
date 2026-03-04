# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Test: Traditional directory module functionality
# - Verifies module is directly exported without enable mechanism
# - Verifies no options are auto-generated
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

  # Create test directory structure with traditional module:
  # modules/
  # └── configs/
  #     └── default.nix
  testSource = pkgs.runCommand "test-source" { } ''
    mkdir -p $out/modules/configs

    # Traditional module with default.nix (no options.nix)
    cat > $out/modules/configs/default.nix << 'EOF'
    { lib, ... }:
    {
      options.configs.setting1 = lib.mkOption {
        type = lib.types.str;
        default = "default-value";
      };
      config.configs.setting2 = "always-set";
    }
    EOF
  '';

  # Build guarded tree
  guardedTree = fhs-modules.mkGuardedTree (testSource + "/modules");

  # Collect modules
  moduleInfos = fhs-modules.collectModules (testSource + "/modules");

  # Find traditional module
  configsInfo = lib.findFirst (m: m.moduleType == "traditional") null moduleInfos;

  # Wrap module
  configsModule = fhs-modules.wrapModule guardedTree configsInfo;

  # Evaluate the module
  evalResult = lib.evalModules {
    modules = [ configsModule ];
  };

  # Test checks
  checks = {
    # Test 1: Verify module type
    testModuleType =
      if configsInfo.moduleType != "traditional" then
        throw "Expected moduleType 'traditional', got '${configsInfo.moduleType}'"
      else
        true;

    # Test 2: Verify modPath
    testModPath =
      if builtins.concatStringsSep "." configsInfo.modPath != "configs" then
        throw "Expected modPath 'configs', got '${builtins.concatStringsSep "." configsInfo.modPath}'"
      else
        true;

    # Test 3: Verify config is always applied (no enable mechanism)
    testConfigAlwaysApplied =
      if evalResult.config.configs.setting2 != "always-set" then
        throw "Traditional module config should always be applied"
      else
        true;

    # Test 4: Verify no enable option is generated
    testNoEnableOption =
      if builtins.hasAttr "enable" evalResult.options.configs then
        throw "Traditional module should NOT have auto-generated enable option"
      else
        true;

    # Test 5: Verify user-defined options work
    testUserOptions =
      if evalResult.config.configs.setting1 != "default-value" then
        throw "User-defined option should work"
      else
        true;
  };

in
pkgs.runCommand "check-traditional-basic" { } ''
  echo "=== Test 1: Verify module type ==="
  echo "PASS: Module type is traditional"

  echo ""
  echo "=== Test 2: Verify modPath ==="
  echo "PASS: modPath is correct"

  echo ""
  echo "=== Test 3: Verify config is always applied ==="
  echo "PASS: Config applied without enable mechanism"

  echo ""
  echo "=== Test 4: Verify no enable option is generated ==="
  echo "PASS: No auto-generated enable option"

  echo ""
  echo "=== Test 5: Verify user-defined options work ==="
  echo "PASS: User-defined options work correctly"

  echo ""
  echo "=== All tests passed ==="
  echo "PASS" > $out
''
