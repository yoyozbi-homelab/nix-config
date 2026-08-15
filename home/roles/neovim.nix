{ config, pkgs, ... }:
{
  home = {
    file = {
      "${config.xdg.configHome}/nvim/lua" = {
        source = ../console/nvim-config/lua;
        recursive = true;
      };
    };
    neovim = {
      enable = true;
      defaultEditor = true;
      withRuby = false;
      withPython3 = true;
      package = pkgs.unstable.neovim-unwrapped;
      initLua = builtins.readFile ../console/nvim-config/init.lua;
    };
  };
}
