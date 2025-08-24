{
  inputs,
  outputs,
  stateVersion,
  ...
}:
{
  # Helper function for generating home-manager configs
  mkHome =
    {
      hostname,
      username,
      desktop ? null,
      platform ? "x86_64-linux",
    }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${platform};
      extraSpecialArgs = {
        inherit
          inputs
          outputs
          desktop
          hostname
          platform
          username
          stateVersion
          ;
      };
      modules = [ ../home-manager ];
    };

  # Helper function for generating host configs
  mkHost =
    {
      hostname,
      username,
      buildHome ? false,
      desktop ? null,
      installer ? null,
      platform ? "x86_64-linux",
    }:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit
          inputs
          outputs
          desktop
          hostname
          platform
          username
          stateVersion
          ;
      };
      modules = [
        ../nixos
        #inputs.agenix.nixosModules.default
      ]
      ++ (inputs.nixpkgs.lib.optionals (installer != null) [ installer ])
      ++ (inputs.nixpkgs.lib.optionals buildHome) [
        inputs.home-manager.nixosModules.home-manager
        {
          specialArgs = {
            inherit
              inputs
              outputs
              desktop
              hostname
              platform
              username
              stateVersion
              ;
          };
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users = {
            ${username} = import ../home-manager; # {
            #inherit outputs inputs stateVersion desktop hostname platform username;
            # pkgs = inputs.nixpkgs.legacyPackages.${platform};
            # lib = inputs.nixpkgs.lib;
            # config =
            # };
            root = import ../home-manager; # {
            # inherit outputs inputs stateVersion desktop hostname platform;
            # pkgs = inputs.nixpkgs.legacyPackages.${platform};
            # lib = inputs.nixpkgs.lib;
            # username = "root";
            # };
          };
        }
      ];
    };

  forAllSystems = inputs.nixpkgs.lib.genAttrs [
    "aarch64-linux"
    "i686-linux"
    "x86_64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];
}
