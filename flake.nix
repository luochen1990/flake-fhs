{
  description = "Test";

  outputs =
    { self, nixpkgs, ... }:
    let

      lib = nixpkgs.lib;
      utils' = lib // (import ./utils/list.nix) // (import ./utils/dict.nix) // (import ./utils/file.nix);
      inherit (import ./utils/prepare-lib.nix utils') prepareLib;
      utils = prepareLib {
        roots = [ ./. ];
        lib = lib;
      };
    in
    utils.mkFlake {
      roots = [ ./. ];
      supportedSystems = [ "x86_64-linux" ];
      inherit self nixpkgs;
      inputs = self.inputs;
    }
    // {
      # Provide lib and mkFlake outputs for backward compatibility with templates
      lib = utils;
      mkFlake = utils.mkFlake;
    };
}
