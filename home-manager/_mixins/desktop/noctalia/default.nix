{ inputs, pkgs, config, hostname, ... }:
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
    enable      = true;
    extraConfig = ''
      local __is_vm      = ${if isVm then "true" else "false"}
      local __polkit_path = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
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
