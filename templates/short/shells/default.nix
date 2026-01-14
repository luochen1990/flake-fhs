{ pkgs, system, ... }:

pkgs.mkShell {
  name = "nix-fhs-dev";

  buildInputs = with pkgs; [
    git
    vim
    curl
    nixfmt
    hello
  ];

  shellHook = ''
    echo "🚀 Welcome to Nix FHS development environment!"
    echo "Available commands: git, vim, curl, nixfmt, hello"
    echo "Try: nix build .#hello-custom"
    echo "System: ${system}"
  '';
}
