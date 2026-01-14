{ pkgs, ... }:

pkgs.mkShell {
  name = "python-development-shell";

  buildInputs = with pkgs; [
    python3
  ];

  shellHook = ''
    echo "🐍 Python Development Environment Ready!"
    echo "Available commands: python3"
  '';
}
