{ config, pkgs, inputs, ... }:
let
  lidCloseScript = pkgs.writeShellScript "lid-close" ''
    if [ "$(acpi -a)" == "Adapter 0: on-line" ]
    then
      hyprctl keyword monitor "eDP-1, disable"
    fi
  '';

  lidOpenScript = pkgs.writeShellScript "lid-open" ''
    hyprctl keyword monitor "eDP-1, enable"
  '';

  lockScript = pkgs.writeShellScript "lock" ''
    #!/usr/bin/env bash
    ${pkgs.grim}/bin/grim -s 1 -l 5 ~/.cache/screenlock.png
    ${pkgs.hyprlock}/bin/hyprlock
  '';
in
{
  home.packages = with pkgs; [
    acpi
    dunst
    swaybg
    sway-audio-idle-inhibit
    kdePackages.xwaylandvideobridge
    wl-clipboard
    cliphist
    networkmanagerapplet
  ];

  wayland.windowManager.hyprland = {
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    enable = true;
    settings = {
      # Monitor configuration - commented examples from original
      monitor = [
        ",highres,auto,auto"
      ];

      # Environment variables
      env = [
        "TERMINAL,ghostty"
        "EDITOR,nvim"
        "BROWSER,zen"
        "__GL_VRR_ALLOWED,1"
        "GDK_BACKEND,wayland,x11,*"
        "QT_QPA_PLATFORM,wayland;xcb"
        "SDL_VIDEODRIVER,wayland"
        "CLUTTER_BACKEND,wayland"
        "WLR_RENDERER_ALLOW_SOFTWARE,1"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "WEBKIT_DISABLE_COMPOSITING_MODE,1"
      ];

      # Debug
      debug = {
        disable_logs = false;
      };

      # Lid switch bindings
      bindl = [
        ",switch:on:Lid Switch,exec,${lidCloseScript}"
        ",switch:off:Lid Switch,exec,${lidOpenScript}"
      ];

      # Startup applications
      exec = [
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "pkill waybar & sleep 0.5 && waybar"
        "swaybg -m fill -i ~/.config/hypr/SLD24_Wallpaper_4K.png"
      ];

      exec-once = [
        "dunst"
        "/nix/store/$(ls -la /nix/store | grep polkit-kde-agent | grep '^d' | awk '{print $9}')/libexec/polkit-kde-authentication-agent-1"
        "shikane -c ~/.config/shikane/config.toml"
        "hypridle"
        "sway-audio-idle-inhibit"
        "sleep 1 && nm-applet"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "sleep 1 && xwaylandvideobridge"
      ];

      # Input configuration
      input = {
        kb_layout = "ch";
        kb_variant = "fr";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
          clickfinger_behavior = 1;
        };
        sensitivity = 0;
      };

      # General appearance
      general = {
        gaps_in = 2;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgb(44475a)";
        "col.inactive_border" = "rgb(282a36)";
        "col.nogroup_border" = "rgb(282a36)";
        "col.nogroup_border_active" = "rgb(44475a)";
        layout = "dwindle";
      };

      # Xwayland
      xwayland = {
        enabled = true;
        force_zero_scaling = true;
      };

      # Miscellaneous
      misc = {
        disable_hyprland_logo = false;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        vfr = true;
      };

      # Decoration
      decoration = {
        rounding = 10;
        blurls = ["lockscreen"];
        shadow = {
          enabled = true;
          range = 60;
          render_power = 3;
          offset = "1 2";
          color = "rgba(1E202966)";
        };
      };

      # Group appearance
      group = {
        groupbar = {
          "col.active" = "rgb(bd93f9) rgb(44475a) 90deg";
          "col.inactive" = "rgb(282a36)";
        };
      };

      # Animations
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 5, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      # Dwindle layout
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      # Master layout
      master = {
        new_on_top = true;
      };

      # Window rules
      windowrulev2 = [
        "opacity 0.8 0.8,class:^(kitty)$"
        "opacity 0.8 0.8,class:^(ghostty)$"
        "opacity 0.8 0.8,class:^(thunar)$"
        "float,class:(floating)"
        "float,class:^(nm-openconnect-auth-dialog)$"
        "opacity 0.0 override,class:^(xwaylandvideobridge)$"
        "noanim,class:^(xwaylandvideobridge)$"
        "noinitialfocus,class:^(xwaylandvideobridge)$"
        "maxsize 1 1,class:^(xwaylandvideobridge)$"
        "noblur,class:^(xwaylandvideobridge)$"
      ];

      # Key bindings
      "$mainMod" = "SUPER";

      bind = [
        "$mainMod, Q, exec, ghostty"
        "$mainMod SHIFT, X, killactive,"
        "$mainMod, L, exec, ${lockScript}"
        "$mainMod, M, exec, wlogout --protocol layer-shell"
        "$mainMod SHIFT, M, exit,"
        "$mainMod, E, exec, dolphin"
        "$mainMod, V, togglefloating,"
        "$mainMod, SPACE, exec, wofi"
        "$mainMod, P, pseudo,"
        "$mainMod, J, togglesplit,"
        "$mainMod, S, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "$mainMod, F, fullscreen, 1"
        "$mainMod SHIFT, F, fullscreen, 0"
        "$mainMod SHIFT, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"
        
        # Hardware keys
        ",211, exec, asusctl profile -n; pkill -SIGRTMIN+8 waybar"
        ",121, exec, pamixer -t"
        ",122, exec, pamixer -d 5"
        ",123, exec, pamixer -i 5"
        ",232, exec, brightnessctl set 10%-"
        ",233, exec, brightnessctl set 10%+"

        # Focus movement
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"

        # Workspace switching
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # Move to workspace
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"

        # Mouse workspace switching
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ];

      # Mouse bindings
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # Gestures
      gesture = [
        "3, horizontal, workspace"
      ];
    };
  };

  # Copy wallpapers that hyprland references (scripts are now inlined above)
  home.file = {
    "${config.xdg.configHome}/hypr/SLD24_Wallpaper_4K.png" = {
      source = ../../assets/wallpapers/SLD24_Wallpaper_4K.png;
    };
    "${config.xdg.configHome}/hypr/hong-kong-night.jpg" = {
      source = ../../assets/wallpapers/hong-kong-night.jpg;
    };
  };
}
