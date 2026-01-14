{ pkgs, ... }:

pkgs.mkShell {
  name = "python-dev";

  buildInputs = with pkgs; [
    python3
  ];

  shellHook = ''
    echo "🐍 Python development environment ready!"
    python3 --version
  '';
}
