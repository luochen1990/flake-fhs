{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
{
  config = mkIf config.my-service.enable {
    # Create user and group
    users.users.${config.my-service.user} = mkIf (config.my-service.user == "myservice") {
      isSystemUser = true;
      group = config.my-service.group;
      description = "My Service daemon user";
    };

    users.groups.${config.my-service.group} = mkIf (config.my-service.group == "myservice") { };

    # Systemd service configuration
    systemd.services.my-service = {
      description = "My Custom Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${config.my-service.package}/bin/hello";
        User = config.my-service.user;
        Group = config.my-service.group;
        Restart = "on-failure";
        RestartSec = 5;

        # Security settings
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;

        # Environment variables
        Environment = mapAttrsToList (k: v: "${k}=${v}") config.my-service.environment;
      };

      # Add port to environment
      environment.PORT = toString config.my-service.port;
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts = mkIf config.my-service.openFirewall [
      config.my-service.port
    ];

    # Add the service package to system packages
    environment.systemPackages = [ config.my-service.package ];
  };
}
