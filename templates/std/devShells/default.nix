{
  pkgs,
  ...
}:

pkgs.mkShell {
  name = "dev-shell";

  packages = with pkgs; [
    git
    curl
    vim
    ripgrep
    jq
  ];

  shellHook = ''
    echo "Welcome to the development shell!"
    echo "Run 'nix run .#hello' to test the package."
  '';
}
