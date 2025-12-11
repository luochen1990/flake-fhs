{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # The module will be automatically discovered and imported
  ];

  # Enable the custom service
  services.my-service = {
    enable = true;
    port = 9090;
  };

  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  system.stateVersion = "24.11";
}