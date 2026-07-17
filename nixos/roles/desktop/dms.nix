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
    # DMS reads user account/avatar info via AccountsService; its system check
    # reports "accountsservice: not available" without this.
    accounts-daemon.enable = true;
  };

  # Fonts DMS expects by default. `nerd-fonts.fira-code` (in the console mixin)
  # registers as "FiraCode Nerd Font", not the "Fira Code" family DMS looks for,
  # so the plain package is needed too; `inter` provides "Inter"/"Inter Variable".
  fonts.packages = with pkgs; [
    inter
    fira-code
  ];

  # DankMaterialShell is quickshell-based; quickshell ships from nixpkgs
  # (cache.nixos.org), so no extra binary cache is required here.
}
