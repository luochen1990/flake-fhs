{
  description = "Full-featured project with modules and profiles using Flake FHS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-fhs.url = "github:luochen1990/flake-fhs";
  };

  outputs = { nixpkgs, flake-fhs, ... }:
    flake-fhs.mkFlake {
      root = [ ./. ];
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" ];
      nixpkgsConfig = {
        allowUnfree = true;
      };
    };
}