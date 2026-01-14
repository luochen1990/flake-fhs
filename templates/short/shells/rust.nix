{ pkgs, system, ... }:

pkgs.mkShell {
  name = "rust-dev";

  buildInputs = with pkgs; [
    rustc
    cargo
    rust-analyzer
    clippy
  ];

  shellHook = ''
    echo "🦀 Rust development environment ready!"
    echo "System: ${system}"
    cargo --version
  '';
}
