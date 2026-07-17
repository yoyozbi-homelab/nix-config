{ ... }:
{
  imports = [
    ../networkmanager.nix
    ../pipewire.nix
  ];
  services = {
    xserver.desktopManager.plasma5.mobile.enable = true;
  };
}
