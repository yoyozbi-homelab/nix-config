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
      
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "25.05";
      libx = import ./lib { inherit inputs outputs stateVersion; };
      
      # Define all hosts in one place
      allHosts = {
        laptop-nix = { username = "yohan"; desktop = "kde"; platform = "x86_64-linux"; };
        surface-nix = { username = "yohan"; desktop = "gnome"; platform = "x86_64-linux"; };
        vm-nix = { username = "yohan"; desktop = "noctalia"; platform = "x86_64-linux"; buildHome = true; };
        ocr1 = { username = "nix"; platform = "aarch64-linux"; };
        tiny1 = { username = "nix"; platform = "x86_64-linux"; };
        tiny2 = { username = "nix"; platform = "x86_64-linux"; };
        rp = { username = "nix"; platform = "aarch64-linux"; };
      };
      
      # Filter server hosts (those without desktop)
      serverHosts = nixpkgs.lib.filterAttrs (name: cfg: (cfg.desktop or null) == null) allHosts;
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        cachix-deploy-lib = cachix-deploy.lib pkgs;
        
        # Filter servers for this system only
        serversForSystem = nixpkgs.lib.filterAttrs (name: cfg: cfg.platform == system) serverHosts;
        
        # Build agents for this system as derivation paths
        agentPaths = builtins.mapAttrs (hostname: cfg:
          (libx.mkHost {
            inherit hostname;
            inherit (cfg) username;
            platform = cfg.platform;
          }).config.system.build.toplevel
        ) serversForSystem;
      in
      {
        defaultPackage = cachix-deploy-lib.spec {
          agents = agentPaths;
        };
      }
    ) // {
      homeConfigurations = {
        "yohan@laptop-nix" = libx.mkHome {
          hostname = "laptop-nix";
          username = "yohan";
          desktop = "kde";
        };
        "yohan@surface-nix" = libx.mkHome {
          hostname = "surface-nix";
          username = "yohan";
          desktop = "gnome";
        };
        "yohan@vm-nix" = libx.mkHome {
          hostname = "vm-nix";
          username = "yohan";
          desktop = "noctalia";
        };
        "yohan@wsl-nix" = libx.mkHome {
          hostname = "wsl-nix";
          username = "yohan";
        };
        "yohan@laptop-omarchy" = libx.mkHome {
            hostname = "laptop-omarchy";
            username = "yohan";
        };
      };
      
      nixosConfigurations = builtins.mapAttrs (hostname: cfg:
        libx.mkHost {
          inherit hostname;
          inherit (cfg) username;
          desktop = cfg.desktop or null;
          buildHome = cfg.buildHome or false;
        }
      ) allHosts;

      overlays = import ./overlays { inherit inputs; };

      # Phase 1 of the TOML restructure (.claude/plans/toml-host-restructure.plan.md):
      # hosts/*/host.toml must stay in sync with the legacy attrsets above until
      # the flake outputs are generated from TOML (Phase 3+).
      checks =
        nixpkgs.lib.genAttrs
          [
            "x86_64-linux"
            "aarch64-linux"
          ]
          (
            system:
            let
              toml = libx.hosts;
              expectHome = [
                "laptop-nix"
                "laptop-omarchy"
                "surface-nix"
                "vm-nix"
                "wsl-nix"
              ];
              expectNetwork = [
                "ocr1"
                "rp"
                "tiny1"
                "tiny2"
              ];
              parity = builtins.all (
                n:
                let
                  t = toml.all.${n};
                  f = allHosts.${n};
                in
                t.username == f.username
                && t.platform == f.platform
                && t.desktop == (f.desktop or null)
                && t.buildHome == (f.buildHome or false)
              ) (builtins.attrNames allHosts);
            in
            {
              host-toml =
                assert nixpkgs.lib.assertMsg (
                  builtins.attrNames toml.nixos == builtins.attrNames allHosts
                ) "host.toml nixos hosts != flake allHosts";
                assert nixpkgs.lib.assertMsg (
                  builtins.attrNames toml.home == expectHome
                ) "host.toml home hosts != legacy homeConfigurations";
                assert nixpkgs.lib.assertMsg (
                  builtins.attrNames toml.network == expectNetwork
                ) "host.toml network sections != legacy hosts.nix data";
                assert nixpkgs.lib.assertMsg parity
                  "host.toml fields (username/platform/desktop/build-home) diverge from flake allHosts";
                nixpkgs.legacyPackages.${system}.writeText "host-toml-check" (builtins.toJSON toml.all);
            }
          );
    };
}
