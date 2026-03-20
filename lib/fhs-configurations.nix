# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Flake FHS configurations output implementation
#
flakeFhsLib:
let
  inherit (builtins)
    listToAttrs
    map
    ;
in
{
  mkConfigurationsOutput =
    args:
    {
      validHosts,
      sharedModules,
      mkEvalContext,
    }:
    let
      inherit (args) lib;
    in
    {
      nixosConfigurations = listToAttrs (
        map (
          host:
          let
            evalContext = mkEvalContext host.info;
            modules = sharedModules ++ [
              (host.path + "/configuration.nix")
            ];
          in
          {
            name = host.name;
            value = lib.nixosSystem {
              inherit (evalContext)
                system
                lib
                ;
              specialArgs = evalContext.specialArgs // {
                hostname = host.name;
              };
              modules = modules ++ [
                { nixpkgs.pkgs = evalContext.pkgs; }
              ];
            };
          }
        ) validHosts
      );
    };
}
