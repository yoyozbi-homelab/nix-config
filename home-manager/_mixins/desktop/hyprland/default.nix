{ config, ... }:
{
  imports = [
    ./waybar.nix
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
      "${config.xdg.configHome}/hypr" = {
        source = ../../dotfiles/hypr;
      };
      "${config.xdg.configHome}/wlogout" = {
        source = ../../dotfiles/wlogout;
      };
      "${config.xdg.configHome}/wofi" = {
        source = ../../dotfiles/wofi;
      };
      "${config.home.homeDirectory}/.icons/Nordzy-hyprcursors" = {
        source = ../../cursor-theme/Nordzy-hyprcursors;
      };
    };
  };

}
