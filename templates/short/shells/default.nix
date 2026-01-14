{ pkgs, system, ... }:

pkgs.mkShell {
  name = "nix-fhs-dev";

  buildInputs = with pkgs; [
    git
    curl
    hello
  ];

  shellHook = ''
    echo "🚀 Welcome to Nix FHS development environment!"
    echo "Available commands: git, curl, hello"
    echo "Try: nix build .#hello-custom"
    echo "System: ${system}"
  '';
}
