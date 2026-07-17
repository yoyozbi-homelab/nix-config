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
    # Noctalia reads user account/avatar info via AccountsService.
    accounts-daemon.enable = true;
  };

  # Fonts noctalia expects by default. `inter` provides "Inter"/"Inter Variable";
  # roboto is noctalia's default UI font; fira-code for terminals.
  fonts.packages = with pkgs; [
    inter
    fira-code
    roboto
  ];

  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
  };
}
