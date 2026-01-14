{ pkgs, ... }:
{
  packages = with pkgs; [
    vim
    git
    nodejs
  ];
}
