{
  description = "Short template with full nixos-config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-fhs.url = "github:luochen1990/Nix-FHS";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-fhs,
      ...
    }:
    nix-fhs.lib.mkFlake {
      inherit self nixpkgs;
      roots = [ ./. ];
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
      ];
      nixpkgsConfig = {
        allowUnfree = true;
      };
    };
}
