{ config, ... }:
{
  imports = [
    ./waybar.nix
  ];

  home = {
    file = {
      "${config.xdg.configHome}/hypr" = {
        source = ../../dotfiles/hypr;
      };
      "${config.xdg.configHome}/shikane" = {
        source = ../../dotfiles/shikane;
      };
      # "${config.xdg.configHome}/waybar" = {
      #   source = ../dotfiles/waybar;
      # };
      "${config.xdg.configHome}/wlogout" = {
        source = ../../dotfiles/wlogout;
      };
      "${config.xdg.configHome}/wofi" = {
        source = ../../dotfiles/wofi;
      };
      "${config.xdg.configHome}/ghostty" = {
        source = ../../dotfiles/ghostty;
      };
      "${config.home.homeDirectory}/.icons/Nordzy-hyprcursors" = {
        source = ../../cursor-theme/Nordzy-hyprcursors;
      };
    };
  };

}
