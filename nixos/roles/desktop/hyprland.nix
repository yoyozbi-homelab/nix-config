{
  inputs,
  pkgs,
  username,
  ...
}:
let
  stable-packages = with pkgs; [
    darkman
    #python311
    #python311Packages.requests
    seahorse
    kdePackages.polkit-kde-agent-1
    imagemagick_light
    brightnessctl
    kdePackages.kwallet
    kdePackages.kwalletmanager
  ];

  unstable-packages = with pkgs.unstable; [
  ];
in
{
  imports = [
    ../networkmanager.nix
    ../pipewire.nix
  ];
  programs = {
    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage =
        inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    };
    # UWSM wraps the compositor in a systemd user session so graphical-session.target,
    # xdg-desktop-autostart.target and D-Bus activation all work correctly. Without it,
    # apps spawned from Hyprland keybinds don't have a working portal or DBUS_SESSION_BUS_ADDRESS.
    uwsm = {
      enable = true;
      waylandCompositors.hyprland = {
        prettyName = "Hyprland";
        comment = "Hyprland compositor managed by UWSM";
        binPath = "/run/current-system/sw/bin/start-hyprland";
      };
    };
    dconf.enable = true;
  };

  environment.systemPackages = stable-packages ++ unstable-packages;

  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          # Use uwsm so the session lands in systemd graphical-session.target
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'uwsm start -- start-hyprland'";
          user = "${username}";
        };
      };
    };
    gvfs.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };

  security = {
    pam.services.hyprlock = { };
    polkit.enable = true;
  };
}
