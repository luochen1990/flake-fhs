{
  config,
  pkgs,
  ...
}:

{
  imports = [
    # Modules are automatically discovered from nixosModules/
  ];

  # Enable our custom web-server module
  services.web-server = {
    enable = true;
    port = 8080;
    openFirewall = true;
    content = "<h1>Welcome to my laptop!</h1><p>Configured via Flake FHS.</p>";
  };

  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  networking.hostName = "laptop";
  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    git
    curl
    vim
  ];

  # Simple user configuration
  users.users.demo = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  system.stateVersion = "24.11";
}
