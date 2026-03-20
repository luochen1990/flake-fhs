# © Copyright 2025 罗宸 (luochen1990@gmail.com, https://lambda.lc)
#
# Flake FHS entry point
#
flakeFhsLib: {
  # Main mkFlake function
  mkFlake =
    {
      self ? inputs.self,
      inputs ? self.inputs,
      nixpkgs ? inputs.nixpkgs,
      lib ? nixpkgs.lib, # 这里用户提供的 lib 是不附带自定义工具函数的标准库lib
    }:
    module:
    let
      # Evaluate config module
      eval = lib.evalModules {
        modules = [
          flakeFhsLib.flakeFhsOptions
          module
        ];
        specialArgs = { inherit lib; };
      };

      config = eval.config;

      # 1. Extract and map options to mkFlakeCore args
      fhsFlake = flakeFhsLib.mkFlakeCore {
        inherit
          inputs
          self
          nixpkgs
          lib
          ;

        supportedSystems = config.systems;
        colmena = config.colmena;
        nixpkgsConfig = config.nixpkgs.config;
        nixpkgsOverlays = config.nixpkgs.overlays;
        layout = config.layout;
        evalContext = config.evalContext;
      };
    in
    lib.recursiveUpdate fhsFlake config.flake;
}
