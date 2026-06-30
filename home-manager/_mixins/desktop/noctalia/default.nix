{ inputs, pkgs, config, lib, hostname, ... }:
let
  # Hyprland needs software-GL fallback and software cursors to run inside a
  # plain QEMU VM (virtio-gpu has no HW cursor planes). Only the VM host needs
  # this; real hardware (laptop-nix) must not force these.
  isVm = hostname == "vm-nix";
in
{
  imports = [
    inputs.noctalia.homeModules.default
    ../hyprland/hypridle.nix
    ../hyprland/hyprlock.nix
    ../hyprland/ghostty.nix
  ];

  programs.noctalia = {
    enable = true;
    settings = {
      general = {
        avatarImage = "${config.home.homeDirectory}/.face";
      };
      location = {
        name = "Zurich, Switzerland";
      };
    };
  };

  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    networkmanagerapplet
    polkit_gnome
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = lib.optionals isVm [ "VIRTUAL-1,1920x1080@60,0x0,1" ] 
                ++ lib.optionals (!isVm) [ ",highres,auto,auto" ];

      env = [
        "TERMINAL,ghostty"
        "EDITOR,nvim"
        "GDK_BACKEND,wayland,x11,*"
        "QT_QPA_PLATFORM,wayland;xcb"
        "SDL_VIDEODRIVER,wayland"
        "CLUTTER_BACKEND,wayland"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "WLR_RENDERER_ALLOW_SOFTWARE,1"
      ]
      ++ lib.optionals isVm [
        "WLR_NO_HARDWARE_CURSORS,1"
      ];

      exec-once = [
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "sleep 0.5 && noctalia"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        "hypridle"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "sleep 1 && nm-applet"
      ];

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

      general = {
        gaps_in = 2;
        gaps_out = 10;
        border_size = 2;
        layout = "dwindle";
      };

      xwayland = {
        enabled = true;
        force_zero_scaling = true;
      };

      misc = {
        disable_hyprland_logo = false;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
      };

      decoration = {
        rounding = 10;
        shadow = {
          enabled = true;
          range = 60;
          render_power = 3;
          offset = "1 2";
          color = "rgba(1E202966)";
        };
      };

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

      dwindle = {
        preserve_split = true;
      };

      "$mainMod" = "SUPER";

      bind = [
        "$mainMod, SPACE, exec, noctalia ipc call launcher toggle"
        "$mainMod SHIFT, C, exec, noctalia ipc call controlCenter toggle"
        "$mainMod, L, exec, noctalia ipc call lockScreen lock"
        "$mainMod, Q, exec, ghostty"
        "$mainMod SHIFT, X, killactive,"
        "$mainMod, E, exec, dolphin"
        "$mainMod, V, togglefloating,"
        "$mainMod, P, pseudo,"
        "$mainMod, F, fullscreen, 1"
        "$mainMod SHIFT, F, fullscreen, 0"
        "$mainMod SHIFT, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"

        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"

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
      ];

      binde = [
        ",XF86AudioRaiseVolume, exec, noctalia ipc call volume increase"
        ",XF86AudioLowerVolume, exec, noctalia ipc call volume decrease"
        ",XF86AudioMute, exec, noctalia ipc call volume muteOutput"
        ",XF86MonBrightnessUp, exec, noctalia ipc call brightness increase"
        ",XF86MonBrightnessDown, exec, noctalia ipc call brightness decrease"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      cursor = {
        no_hardware_cursors = true;
      };
    };
  };

  xdg = {
    enable = true;
    mime.enable = true;
  };
}
