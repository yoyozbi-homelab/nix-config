{ ... }:
{
  imports = [
    ../services/networkmanager.nix
    ../services/pipewire.nix
  ];
  services = {
    xserver.desktopManager.plasma5.mobile.enable = true;
  };
}
