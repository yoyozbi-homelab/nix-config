{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    lanzaboote.url = "github:nix-community/lanzaboote";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    cachix-deploy.url = "github:cachix/cachix-deploy-flake";
    deploy-rs.url = "github:serokell/deploy-rs";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    flake-utils.url = "github:numtide/flake-utils";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
  };

  outputs =
    {
      self,
      nixpkgs,
      deploy-rs,
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
      };
      
      nixosConfigurations = builtins.mapAttrs (hostname: cfg:
        libx.mkHost {
          inherit hostname;
          inherit (cfg) username;
          desktop = cfg.desktop or null;
        }
      ) allHosts;

      deploy.nodes = {
        surface-nix = {
          hostname = "surface-nix";
          profiles.system = {
            user = "root";
            sshUser = "yohan";
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.surface-nix;
          };
        };
      };

      overlays = import ./overlays { inherit inputs; };
    };
}
