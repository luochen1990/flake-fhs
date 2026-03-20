# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Flake FHS colmena implementation
#
flakeFhsLib:
let
  inherit (builtins)
    head
    listToAttrs
    map
    substring
    ;
in
{
  mkColmenaOutput =
    args:
    {
      validHosts,
      sharedModules,
      mkEvalContext,
    }:
    let
      inherit (args)
        nixpkgs
        inputs
        supportedSystems
        colmena
        ;

      # This module makes colmena & nixosConfigurations produce exactly the same toplevel outPath
      colmenaShimModule = {
        # Fix VersionName diff between colmena & nixosConfigurations
        system.nixos.revision = nixpkgs.rev or nixpkgs.dirtyRev or null;
        system.nixos.versionSuffix =
          if nixpkgs ? lastModifiedDate && nixpkgs ? shortRev then
            ".${substring 0 8 nixpkgs.lastModifiedDate}.${nixpkgs.shortRev}"
          else
            "";
        # Fix NIX_PATH diff between colmena & nixosConfigurations
        nixpkgs.flake.source = nixpkgs.outPath;
      };
    in
    if colmena.enable then
      {
        colmenaHive = inputs.colmena.lib.makeHive (
          {
            meta = {
              nixpkgs = (mkEvalContext { system = head supportedSystems; }).pkgs;
              nodeNixpkgs = listToAttrs (
                map (host: {
                  name = host.name;
                  value = (mkEvalContext host.info).pkgs;
                }) validHosts
              );
              nodeSpecialArgs = listToAttrs (
                map (
                  host:
                  let
                    evalContext = mkEvalContext host.info;
                  in
                  {
                    name = host.name;
                    value = evalContext.specialArgs // {
                      hostname = host.name;
                    };
                  }
                ) validHosts
              );
            };
          }
          // listToAttrs (
            map (host: {
              name = host.name;
              value = {
                deployment.allowLocalDeployment = true;
                imports = sharedModules ++ [
                  (host.path + "/configuration.nix")
                  colmenaShimModule
                ];
              };
            }) validHosts
          )
        );
      }
    else
      { };
}
