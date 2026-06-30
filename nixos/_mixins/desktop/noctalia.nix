{ lib, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
  ];

  programs.hyprland = {
    package = lib.mkForce pkgs.hyprland;
    portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;
  };

  hardware.bluetooth.enable = true;

  services = {
    upower.enable = true;
    power-profiles-daemon.enable = true;
  };

  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
  };
}
