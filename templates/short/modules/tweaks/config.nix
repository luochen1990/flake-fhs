{ ... }:

{
  # Enable flakes and nix-command
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Use caps as ctrl
  services.xserver.xkb.options = "terminate:ctrl_alt_bksp,ctrl:nocaps";
}
