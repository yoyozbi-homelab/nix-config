{
  config,
  desktop,
  hostname,
  inputs,
  lib,
  outputs,
  pkgs,
  stateVersion,
  username,
  platform,
  ...
}:
{
  imports =
    lib.optional (builtins.isPath (./. + "/_mixins/users/${username}")) ./_mixins/users/${username}
    ++ lib.optional (builtins.pathExists (
      ./. + "/_mixins/users/${username}/hosts/${hostname}.nix"
    )) ./_mixins/users/${username}/hosts/${hostname}.nix
    ++ lib.optional (desktop != null) ./_mixins/desktop;
  home = {
    # activation.report-changes = config.lib.dag.entryAnywhere ''
    # 	${pkgs.nvd}/bin/nvd diff $oldGenPath $newGenPath
    # '';
    homeDirectory = "/home/${username}";
    inherit stateVersion;
    inherit username;
  };

  # Workaround home-manager bug with flakes
  # - https://github.com/nix-community/home-manager/issues/2033
  news.display = "silent";

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      #inputs.agenix.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree pakages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
    # mkDefault so the home-manager NixOS module (buildHome) can forward the
    # system's nix.package without conflicting; standalone home configs still
    # get unstable.nix as there is no competing definition.
    package = lib.mkDefault pkgs.unstable.nix;

    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Avoid unwanted garbage collection when using nix-direnv
      keep-outputs = true;
      keep-derivations = true;
      warn-dirty = false;
    };
  };
}
