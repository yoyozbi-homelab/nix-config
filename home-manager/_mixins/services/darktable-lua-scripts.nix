{ config, pkgs, ... }:

let
  # Create a derivation for the darktable lua-scripts repository
  darktable-lua-scripts = pkgs.stdenv.mkDerivation {
    pname = "darktable-lua-scripts";
    version = "master";

    src = pkgs.fetchFromGitHub {
      owner = "darktable-org";
      repo = "lua-scripts";
      rev = "aed3275943f218e559c58b98579ceafb02e220da";
      sha256 = "1pgam92d8crvmpn4a3z0hfajxmkj73p15d74agqdi3cv3a9k84dx";
    };

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
  };
in
{
  home.file = {
    "${config.xdg.configHome}/darktable/lua" = {
      source = darktable-lua-scripts;
      recursive = true;
    };
    "${config.xdg.configHome}/darktable/luarc" = {
      text = ''
        require "tools/script_manager"
      '';
    };
  };
}
