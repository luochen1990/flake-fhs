{ config, lib, pkgs, ... }:
{
  config = {
    systemd.services.my-service = {
      description = "My Custom Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${config.services.my-service.package}/bin/hello --port ${toString config.services.my-service.port}";
        Restart = "always";
      };
    };

    # Add the service to the system environment
    environment.systemPackages = [ config.services.my-service.package ];
  };
}