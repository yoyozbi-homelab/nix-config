{ config, ... }:
{
  imports = [
    ./hyprland.nix
    ./hypridle.nix
    ./hyprlock.nix
    ./waybar.nix
    ./wofi.nix
    ./wlogout.nix
    ./ghostty.nix
    ./shikane.nix
  ];

  xdg = {
    enable = true;
    mime = {
      enable = true;
    };
    mimeApps = {
      enable = true;

      defaultApplications = {
        "image/png" = "org.kde.gwenview.desktop";
      };
    };
  };

  home = {
    file = {
      "${config.home.homeDirectory}/.icons/Nordzy-hyprcursors" = {
        source = ../../cursor-theme/Nordzy-hyprcursors;
      };
    };
  };

}
