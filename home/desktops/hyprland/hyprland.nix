{ config, pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    acpi
    dunst
    swaybg
    sway-audio-idle-inhibit
    wl-clipboard
    cliphist
    networkmanagerapplet
  ];

  wayland.windowManager.hyprland = {
    package       = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    enable        = true;
    configType    = "lua";
    extraConfig   = ''
      require("conf/main")
    '';
  };

  xdg.configFile = {
    "hypr/conf/main.lua".source      = ./lua/main.lua;
    "hypr/conf/binds.lua".source     = ./lua/binds.lua;
    "hypr/conf/rules.lua".source     = ./lua/rules.lua;
    "hypr/conf/autostart.lua".source = ./lua/autostart.lua;
  };

  home.file = {
    "${config.xdg.configHome}/hypr/SLD24_Wallpaper_4K.png" = {
      source = ../../assets/wallpapers/SLD24_Wallpaper_4K.png;
    };
    "${config.xdg.configHome}/hypr/hong-kong-night.jpg" = {
      source = ../../assets/wallpapers/hong-kong-night.jpg;
    };
    "${config.xdg.configHome}/hypr/scripts/lid-close.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        if [ "$(acpi -a)" == "Adapter 0: on-line" ]; then
          hyprctl keyword monitor "eDP-1, disable"
        fi
      '';
    };
    "${config.xdg.configHome}/hypr/scripts/lid-open.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        hyprctl keyword monitor "eDP-1, enable"
      '';
    };
    "${config.xdg.configHome}/hypr/scripts/lock.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        grim -s 1 -l 5 ~/.cache/screenlock.png
        hyprlock
      '';
    };
  };
}
