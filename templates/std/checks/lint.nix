{
  pkgs,
  lib,
  ...
}:

pkgs.runCommand "lint-check"
  {
    nativeBuildInputs = with pkgs; [
      deadnix
      statix
    ];
  }
  ''
    echo "🔍 Running linting checks..."

    exit_code=0

    # Check for dead code with deadnix
    echo "Checking for dead code..."
    if ! deadnix --fail .; then
      echo "❌ Found dead code that should be removed"
      echo "Run: deadnix --edit ."
      exit_code=1
    fi

    # Check for issues with statix
    echo "Checking for Nix best practices..."
    if ! statix check .; then
      echo "❌ Found Nix style issues"
      echo "Run: statix fix ."
      exit_code=1
    fi

    if [ $exit_code -eq 0 ]; then
      echo "✅ All linting checks passed"
    else
      echo "❌ Linting issues found"
      exit 1
    fi

    touch $out
  ''
