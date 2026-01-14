{
  pkgs,
  lib,
  ...
}:

pkgs.runCommand "format-check"
  {
    nativeBuildInputs = with pkgs; [
      nixfmt-tree
      alejandra
    ];
  }
  ''
    echo "🔍 Running format checks..."

    # Check if all Nix files are properly formatted
    exit_code=0

    # Find all .nix files and check formatting
    for file in $(find . -name "*.nix" -type f); do
      echo "Checking $file..."
      if ! nixfmt --check "$file"; then
        echo "❌ $file is not properly formatted"
        echo "Run: nixfmt $file"
        exit_code=1
      fi
    done

    if [ $exit_code -eq 0 ]; then
      echo "✅ All Nix files are properly formatted"
    else
      echo "❌ Some files need formatting"
      exit 1
    fi

    touch $out
  ''
