{
  desktop,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages =
    with pkgs;
    [
      alsa-utils
      pulseaudio
      pulsemixer
    ]
    ++ lib.optionals (desktop != null) [
      pavucontrol
    ];

  security.rtkit.enable = true;
  services = {
    pulseaudio.enable = lib.mkForce false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };
  };
}
