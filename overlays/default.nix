# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: _prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });

    # See the nixpkgs-bws input in flake.nix for why this is pinned.
    inherit
      (import inputs.nixpkgs-bws {
        inherit (final.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      })
      bws
      ;
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
    master = import inputs.nixpkgs-master {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };
}
