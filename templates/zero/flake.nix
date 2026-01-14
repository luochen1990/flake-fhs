{
  description = "Minimal template - only flake.nix";

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
    };
}
