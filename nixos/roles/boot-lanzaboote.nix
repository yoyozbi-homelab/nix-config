{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];
  boot = {
    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
    loader = {
      efi = {
        canTouchEfiVariables = true;
      };
      systemd-boot = {
        enable = lib.mkForce false;
      };
    };
  };
  environment.systemPackages = with pkgs; [
    sbctl
  ];
}
