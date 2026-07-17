{ inputs, pkgs, config, hostname, ... }:
let
  # Hyprland needs software-GL fallback and software cursors to run inside a
  # plain QEMU VM (virtio-gpu has no HW cursor planes). Only the VM host needs
  # this; real hardware must not force these.
  isVm = hostname == "vm-nix";
in
{
  imports = [
    inputs.noctalia.homeModules.default
    #../hyprland/hyprlock.nix
    #../hyprland/hypridle.nix
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
    libnotify
  ];

  wayland.windowManager.hyprland = {
    enable      = true;
    configType    = "lua";
    # These are assigned as GLOBALS (no `local`) on purpose: `require("conf/noctalia")`
    # loads main.lua in its own scope, and Lua locals from this chunk are not
    # visible there. Only globals cross the require boundary, so `local` here
    # would make __is_vm read as nil (falsy) inside main.lua.
    extraConfig = ''
      __is_vm      = ${if isVm then "true" else "false"}
      __polkit_path = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      require("conf/noctalia")
    '';
  };

  xdg = {
    enable = true;
    mime.enable = true;
    configFile = {
      "hypr/conf/noctalia.lua".source = ./lua/main.lua;
    };
  };
}
