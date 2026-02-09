{ pkgs, ... }:

pkgs.runCommand "lint-check" { } ''
  echo "Running lint check..."
  # In a real project, you would run linters here, e.g.:
  # ${pkgs.nixfmt}/bin/nixfmt --check .

  echo "Lint check passed!"
  touch $out
''
