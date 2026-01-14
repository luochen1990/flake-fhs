{ pkgs, ... }:
{
  packages = with pkgs; [
    git
    nodejs
  ];
}
