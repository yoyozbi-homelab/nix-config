{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    lanzaboote.url = "github:nix-community/lanzaboote";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    cachix-deploy.url = "github:cachix/cachix-deploy-flake";
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";

    noctalia = {
      url = "github:noctalia-dev/noctalia";
      # intentionally omitting nixpkgs.follows to enable binary cache at noctalia.cachix.org
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cachix-deploy,
      flake-utils,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      stateVersion = "25.05";
      libx = import ./lib { inherit inputs outputs stateVersion; };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        cachix-deploy-lib = cachix-deploy.lib pkgs;
        agentPaths = builtins.mapAttrs (
          hostname: data: (libx.mkHostFromToml data).config.system.build.toplevel
        ) (nixpkgs.lib.filterAttrs (_: data: data.platform == system) libx.hosts.deploy);
      in
      {
        formatter = pkgs.writeShellApplication {
          name = "fmt";
          runtimeInputs = [ pkgs.nixfmt ];
          text = ''
            find "$@" -name '*.nix' -not -path '*/.git/*' -print0 \
              | xargs -0 nixfmt
          '';
        };
        defaultPackage = cachix-deploy-lib.spec { agents = agentPaths; };
      }
    )
    // {
      nixosConfigurations = builtins.mapAttrs (_: libx.mkHostFromToml) libx.hosts.nixos;

      homeConfigurations = nixpkgs.lib.mapAttrs' (
        hostname: data: nixpkgs.lib.nameValuePair "${data.username}@${hostname}" (libx.mkHomeFromToml data)
      ) libx.hosts.home;

      overlays = import ./overlays { inherit inputs; };

      checks = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
        host-toml = nixpkgs.legacyPackages.${system}.writeText "host-toml-check" (
          builtins.toJSON libx.hosts.all
        );
      });
    };
}
