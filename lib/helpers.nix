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
      ++ (inputs.nixpkgs.lib.optionals buildHome [
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            # false: the shared home-manager/default.nix sets nixpkgs.* (overlays
            # + config) which standalone home configs need; useGlobalPkgs would
            # forbid those. Let home-manager build its own pkgs with our overlays.
            useGlobalPkgs = false;
            useUserPackages = true;
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
            users.${username} = import ../home-manager;
          };
        }
      ]);
    };

  forAllSystems = inputs.nixpkgs.lib.genAttrs [
    "aarch64-linux"
    "i686-linux"
    "x86_64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];
}
