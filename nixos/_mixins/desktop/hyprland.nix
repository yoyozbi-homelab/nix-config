{
  inputs,
  pkgs,
  username,
  ...
}:
let
  stable-packages = with pkgs; [
    darkman
    python311
    python311Packages.requests
    seahorse
    libsForQt5.polkit-kde-agent
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
    ../services/networkmanager.nix
    ../services/pipewire.nix
  ];
  programs = {
    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage =
        inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    };
    dconf.enable = true;
  };

  environment.systemPackages = stable-packages ++ unstable-packages;

  services = {
    greetd = {
      enable = false; # Would need to be set to true to have this greeter
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
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
