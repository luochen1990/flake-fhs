{
  description = "Flake FHS - Filesystem Hierarchy Standard for Nix flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      # Get mkFlake function from Level 3 utils
      mkFlake =
        ((import ./utils/utils.nix).prepareUtils ./utils.more { lib = nixpkgs.lib; }.more {
          pkgs = nixpkgs;
        }).mkFlake;
    in
    (mkFlake {
      root = [ ./. ];
      inherit (inputs) self;
      lib = nixpkgs.lib;
      nixpkgs = nixpkgs;
      inherit inputs;
    })
    // {
      # Export mkFlake function for external use
      mkFlake =
        args:
        mkFlake (
          args
          // {
            inputs = args.inputs or inputs;
          }
        );
    };
}
