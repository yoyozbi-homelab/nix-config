{ pkgs, ... }:
{
  imports = [
    ../networkmanager.nix
  ];
  services = {
    xserver = {
      enable = true;
      desktopManager = {
        gnome = {
          enable = true;
        };
      };
      displayManager = {
        gdm = {
          enable = true;
        };
      };
    };
    gvfs.enable = true;

    gnome = {
      gnome-keyring = {
        enable = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    gnomeExtensions.appindicator
  ];
}
