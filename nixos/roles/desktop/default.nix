{
  desktop,
  lib,
  ...
}:
{
  imports = lib.optional (builtins.pathExists (./. + "/${desktop}.nix")) ./${desktop}.nix;

  hardware = {
    graphics = {
      enable = true;
    };
  };

  programs.dconf.enable = true;
}
