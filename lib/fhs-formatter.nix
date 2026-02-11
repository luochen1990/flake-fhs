# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Flake FHS formatter implementation
#
flakeFhsLib:
let
  inherit (builtins)
    pathExists
    ;
in
{
  mkFormatterOutput =
    args:
    {
      eachSystem,
    }:
    let
      inherit (args) self inputs;
    in
    {
      formatter = eachSystem (
        { pkgs, ... }:
        let
          treefmtNix = self.outPath + "/treefmt.nix";
          treefmtToml = self.outPath + "/treefmt.toml";
        in
        if (inputs ? treefmt-nix) && pathExists treefmtNix then
            (inputs.treefmt-nix.lib.evalModule pkgs treefmtNix).config.build.wrapper
        else if pathExists treefmtToml then
          pkgs.treefmt.withConfig { configFile = treefmtToml; }
        else
          pkgs.nixfmt-tree
      );
    };
}
