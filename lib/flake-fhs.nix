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
        optionsMode = config.optionsMode;
        colmena = config.colmena;
        nixpkgsConfig = config.nixpkgs.config;
        layout = config.layout;
        systemContext = config.systemContext;
      };
    in
    lib.recursiveUpdate fhsFlake config.flake;
}
