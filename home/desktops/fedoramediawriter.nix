{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mediawriter
  ];
}
