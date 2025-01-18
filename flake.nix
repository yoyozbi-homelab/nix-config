{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    lanzaboote.url = "github:nix-community/lanzaboote";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    cachix-deploy.url = "github:cachix/cachix-deploy-flake";
    deploy-rs.url = "github:serokell/deploy-rs";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-formatter-pack = {
      url = "github:Gerschtli/nix-formatter-pack";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
  };

  outputs =
    { self
    , nixpkgs
    , nix-formatter-pack
    , deploy-rs
    , ...
    } @ inputs:
    let
      inherit (self) outputs;
      system = "x86_64-linux";

      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = "23.11";
      libx = import ./lib { inherit inputs outputs stateVersion; };
    in
    {
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
      nixosConfigurations = {
        "laptop-nix" = libx.mkHost {
          hostname = "laptop-nix";
          username = "yohan";
          desktop = "kde";
        };
        "surface-nix" = libx.mkHost {
          hostname = "surface-nix";
          username = "yohan";
          desktop = "gnome";
        };
        "tiny1" = libx.mkHost {
          hostname = "tiny1";
          username = "nix";
        };
        "tiny2" = libx.mkHost {
          hostname = "tiny2";
          username = "nix";
        };
        "ocr1" = libx.mkHost {
          hostname = "ocr1";
          username = "nix";
        };
        "rp" = libx.mkHost {
          hostname = "rp";
          username = "nix";
        };
      };

      packages.${system} = {
        hosts = {
          tiny1 = self.nixosConfigurations."tiny1".config.system.build.toplevel;
          ocr1 = self.nixosConfigurations."ocr1".config.system.build.toplevel;
          tiny2 = self.nixosConfigurations."tiny2".config.system.build.toplevel;
        };

      
      #rp = self.nixosConfigurations."rp".config.system.build.toplevel;
      };

      packages.aarch64-linux = {
        hosts = {
          ocr1 = self.nixosConfigurations."ocr1".config.system.build.toplevel;
        };
      };

      deploy.nodes = {
        surface-nix = {
            hostname = "surface-nix";
            profiles.system = {
              user = "root";
              sshUser = "yohan";
              path =  deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.surface-nix;
            };
        };
      };

      formatter = libx.forAllSystems (
        nix-formatter-pack.lib.mkFormatter {
          pkgs = nixpkgs.legacyPackages.${system};
          config.tools = {
            alejandra.enable = true;
            deadnix.enable = true;
            nixpkgs-fmt.enable = true;
            statix.enable = true;
          };
        }
      );

      overlays = import ./overlays { inherit inputs; };
    };
}
