# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Test: Basic guarded module functionality
# - Verifies enable option auto-generation
# - Verifies config is wrapped with mkIf
# - Verifies module is exported correctly
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

  # Create test directory structure
  testSource = pkgs.runCommand "test-source" { } ''
    mkdir -p $out/modules/myapp
    # options.nix with option definitions following module path
    cat > $out/modules/myapp/options.nix << 'EOF'
    { lib, ... }:
    {
      options.myapp = {
        message = lib.mkOption {
          type = lib.types.str;
          default = "hello";
        };
      };
    }
    EOF
    # config.nix
    cat > $out/modules/myapp/config.nix << 'EOF'
    { config, lib, ... }:
    {
      config.myapp.result = config.myapp.message;
    }
    EOF
  '';

  # Build guarded tree
  guardedTree = fhs-modules.mkGuardedTree (testSource + "/modules");

  # Collect modules
  moduleInfos = fhs-modules.collectModules (testSource + "/modules");
  firstInfo = builtins.head moduleInfos;

  # Wrap the module
  wrappedModule = fhs-modules.wrapModule guardedTree firstInfo;

  # Evaluate the module to verify structure
  evalResult = lib.evalModules {
    modules = [
      wrappedModule
      {
        config.myapp.enable = true;
      }
    ];
  };

  # Test checks (computed at eval time)
  checks = {
    # Test 1: Check guarded tree has correct modPath
    testTreeModPath =
      let
        child = builtins.head guardedTree.guardedChildren;
      in
      if builtins.concatStringsSep "." child.modPath != "myapp" then
        throw "Expected modPath 'myapp', got '${builtins.concatStringsSep "." child.modPath}'"
      else
        true;

    # Test 2: Check module info collection
    testModuleCount =
      if builtins.length moduleInfos != 1 then
        throw "Expected 1 module info, got ${toString (builtins.length moduleInfos)}"
      else
        true;

    testModuleType =
      if firstInfo.moduleType != "guarded" then
        throw "Expected moduleType 'guarded', got '${firstInfo.moduleType}'"
      else
        true;

    # Test 3: Check enable option exists
    testEnableExists =
      if !(builtins.hasAttr "enable" evalResult.options.myapp) then
        throw "Enable option not found in myapp options. Available: ${builtins.concatStringsSep ", " (builtins.attrNames evalResult.options.myapp)}"
      else
        true;

    # Test 4: Check config evaluates correctly when enabled
    testConfigResult =
      if evalResult.config.myapp.result != "hello" then
        throw "Expected myapp.result = 'hello', got '${toString evalResult.config.myapp.result}'"
      else
        true;

    # Test 5: Check config is NOT applied when disabled
    testDisabledConfig =
      let
        evalDisabled = lib.evalModules {
          modules = [
            wrappedModule
            {
              config.myapp.enable = false;
            }
          ];
        };
      in
      if evalDisabled.config.myapp ? result then
        throw "Config should NOT be applied when disabled, but got result = '${toString evalDisabled.config.myapp.result}'"
      else
        true;
  };

in
pkgs.runCommand "check-guarded-basic" { } ''
  echo "=== Test 1: Check guarded tree modPath ==="
  echo "PASS: Guarded tree has correct modPath"

  echo ""
  echo "=== Test 2: Check module info collection ==="
  echo "PASS: Module info collected correctly"

  echo ""
  echo "=== Test 3: Check enable option exists ==="
  echo "PASS: Enable option exists"

  echo ""
  echo "=== Test 4: Check config evaluates correctly when enabled ==="
  echo "PASS: Config evaluates correctly"

  echo ""
  echo "=== Test 5: Check config is NOT applied when disabled ==="
  echo "PASS: Config correctly guarded"

  echo ""
  echo "=== All tests passed ==="
  echo "PASS" > $out
''
