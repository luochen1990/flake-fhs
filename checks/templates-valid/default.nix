# Test that templates work with current flake-fhs
{ pkgs, lib, flake-fhs, ... }:

let
  # Test that verifies templates use GitHub URL and work with local flake-fhs
  templatesTest = pkgs.runCommand "templates-valid-test" {
    nativeBuildInputs = [ pkgs.nix pkgs.jq ];
  } ''
    set -e

    echo "Testing templates validity..."

    # Test 1: Verify template uses GitHub URL (not local path)
    echo "✅ Test 1: Checking template uses GitHub URL"
    if grep -q "github:luochen1990/flake-fhs" ${../../templates/simple-project/flake.nix}; then
      echo "✅ Template uses correct GitHub URL"
    else
      echo "❌ Template does not use GitHub URL"
      exit 1
    fi

    # Test 2: Create temp directory and test template with local flake-fhs
    echo "✅ Test 2: Testing template with local flake-fhs"
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    # Copy template to temp directory
    cp -r ${../../templates/simple-project}/* $temp_dir/

    # Replace GitHub URL with local path for testing
    sed -i 's|github:luochen1990/flake-fhs|path:'${builtins.toString ../.}'|g' $temp_dir/flake.nix

    # Verify the replacement worked
    if grep -q "path:" $temp_dir/flake.nix; then
      echo "✅ GitHub URL replaced with local path for testing"
    else
      echo "❌ Failed to replace GitHub URL"
      exit 1
    fi

    # Test 3: Run nix flake check in the temp directory
    echo "✅ Test 3: Running nix flake check on template..."
    cd $temp_dir
    nix --extra-experimental-features nix-command --extra-experimental-features flakes flake check --no-build --quiet

    # Test 4: Verify the template generates expected outputs
    echo "✅ Test 4: Verifying template outputs"
    nix --extra-experimental-features nix-command --extra-experimental-features flakes flake show --json | jq -r '.packages | keys | length' > packages_count
    if [ "$(cat packages_count)" -gt 0 ]; then
      echo "✅ Template generates packages"
    else
      echo "❌ Template does not generate packages"
      exit 1
    fi

    echo "🎉 All template tests passed!"
    echo "✅ Template uses GitHub URL for users"
    echo "✅ Template works with current local flake-fhs"
    echo "✅ Template passes nix flake check"
    echo "✅ Template generates expected outputs"
  '';

  # Test that current flake-fhs.lib.mkFlake works correctly
  mkFlakeTest = pkgs.runCommand "mkflake-test" {} ''
    # Test basic mkFlake functionality
    cat > test-flake.nix << 'EOF'
{
  description = "Test flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-fhs.url = "path:${builtins.toString ../.}";
  };

  outputs = { self, nixpkgs, flake-fhs, ... }:
    flake-fhs.lib.mkFlake {
      inherit self nixpkgs;
      lib = nixpkgs.lib;
      root = [ ./. ];
      nixpkgsConfig = {
        allowUnfree = true;
      };
    };
}
EOF

    # Test that it can be evaluated
    nix-instantiate --eval --expr 'let flake = import ./test-flake.nix; in builtins.attrNames flake.outputs { self = {}; nixpkgs = import ${pkgs.path}; flake-fhs = import ${../.} {}; }' > $out

    if [ $? -eq 0 ]; then
      echo "✅ mkFlake test passed!" >> $out
    else
      echo "❌ mkFlake test failed!" >&2
      exit 1
    fi
  '';

in
{
  # Main templates validation test
  templates-test = templatesTest;

  # Basic mkFlake functionality test
  mkflake-test = mkFlakeTest;
}