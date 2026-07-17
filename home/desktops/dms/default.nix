{ inputs, pkgs, hostname, ... }:
let
  # Hyprland needs software-GL fallback and software cursors to run inside a
  # plain QEMU VM (virtio-gpu has no HW cursor planes). Only the VM host needs
  # this; real hardware must not force these.
  isVm = hostname == "vm-nix";
in
{
  imports = [
    inputs.dms.homeModules.dank-material-shell
    #../hyprland/hyprlock.nix
    #../hyprland/hypridle.nix
    ../hyprland/ghostty.nix
  ];

  # DankMaterialShell (quickshell). `enable` applies sensible defaults; the
  # Hyprland integration is driven from the lua config below (dms run + dms ipc).
  programs.dank-material-shell.enable = true;

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
    # These are assigned as GLOBALS (no `local`) on purpose: `require("conf/dms")`
    # loads main.lua in its own scope, and Lua locals from this chunk are not
    # visible there. Only globals cross the require boundary, so `local` here
    # would make __is_vm read as nil (falsy) inside main.lua.
    extraConfig = ''
      __is_vm      = ${if isVm then "true" else "false"}
      __polkit_path = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      require("conf/dms")
    '';
  };

  xdg = {
    enable = true;
    mime.enable = true;
    configFile = {
      "hypr/conf/dms.lua".source = ./lua/main.lua;
    };
  };
}
