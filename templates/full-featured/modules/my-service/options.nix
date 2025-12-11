{ config, lib, pkgs, ... }:
with lib;
{
  # Service options
  port = mkOption {
    type = types.port;
    default = 8080;
    description = "Port on which my-service should listen";
  };

  package = mkOption {
    type = types.package;
    default = pkgs.hello;
    description = "My service package to use";
  };
}