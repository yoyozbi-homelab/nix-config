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
      
      # Hosts still using the legacy mkHost generator (shrinks as Phase 3 proceeds)
      # All hosts migrated — allHosts will be removed in Phase 5 cleanup
      allHosts = { };

      # Filter server hosts (those without desktop)
      serverHosts = nixpkgs.lib.filterAttrs (name: cfg: (cfg.desktop or null) == null) allHosts;

      # TOML-migrated server hosts (grows as Phase 3 proceeds)
      migratedServerHosts = nixpkgs.lib.filterAttrs
        (name: data: data.nixos && data.desktop == null)
        { inherit (libx.hosts.all) tiny1 tiny2 ocr1 rp; };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        cachix-deploy-lib = cachix-deploy.lib pkgs;

        # Legacy servers for this system
        serversForSystem = nixpkgs.lib.filterAttrs (name: cfg: cfg.platform == system) serverHosts;
        # TOML-migrated servers for this system
        migratedServersForSystem = nixpkgs.lib.filterAttrs (name: data: data.platform == system) migratedServerHosts;

        # Build agents for this system as derivation paths (legacy + TOML-migrated)
        agentPaths =
          builtins.mapAttrs (hostname: cfg:
            (libx.mkHost {
              inherit hostname;
              inherit (cfg) username;
              platform = cfg.platform;
            }).config.system.build.toplevel
          ) serversForSystem
          //
          builtins.mapAttrs (hostname: data:
            (libx.mkHostFromToml data).config.system.build.toplevel
          ) migratedServersForSystem;
      in
      {
        defaultPackage = cachix-deploy-lib.spec {
          agents = agentPaths;
        };
      }
    ) // {
      homeConfigurations = {
        "yohan@laptop-nix"  = libx.mkHomeFromToml libx.hosts.all.laptop-nix;
        "yohan@surface-nix" = libx.mkHomeFromToml libx.hosts.all.surface-nix;
        "yohan@vm-nix" = libx.mkHomeFromToml libx.hosts.all.vm-nix;
        "yohan@wsl-nix" = libx.mkHome {
          hostname = "wsl-nix";
          username = "yohan";
        };
        "yohan@laptop-omarchy" = libx.mkHome {
            hostname = "laptop-omarchy";
            username = "yohan";
        };
      };
      
      nixosConfigurations =
        builtins.mapAttrs (hostname: cfg:
          libx.mkHost {
            inherit hostname;
            inherit (cfg) username;
            desktop = cfg.desktop or null;
            buildHome = cfg.buildHome or false;
          }
        ) allHosts
        // {
          vm-nix = libx.mkHostFromToml libx.hosts.all.vm-nix;
          tiny1  = libx.mkHostFromToml libx.hosts.all.tiny1;
          tiny2  = libx.mkHostFromToml libx.hosts.all.tiny2;
          ocr1        = libx.mkHostFromToml libx.hosts.all.ocr1;
          rp          = libx.mkHostFromToml libx.hosts.all.rp;
          surface-nix = libx.mkHostFromToml libx.hosts.all.surface-nix;
          laptop-nix  = libx.mkHostFromToml libx.hosts.all.laptop-nix;
        };

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
              # Hosts fully migrated to mkHostFromToml (grows during Phase 3)
              migratedHosts = [ "laptop-nix" "ocr1" "rp" "surface-nix" "tiny1" "tiny2" "vm-nix" ];
              allHostNames =
                nixpkgs.lib.sort nixpkgs.lib.lessThan
                  (builtins.attrNames allHosts ++ migratedHosts);
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
                assert nixpkgs.lib.assertMsg
                  (nixpkgs.lib.sort nixpkgs.lib.lessThan (builtins.attrNames toml.nixos) == allHostNames)
                  "host.toml nixos hosts != nixosConfigurations";
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
