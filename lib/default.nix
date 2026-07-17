{
  inputs,
  outputs,
  stateVersion,
  ...
}:
let
  helpers = import ./helpers.nix { inherit inputs outputs stateVersion; };
  hosts = import ./hosts.nix { inherit inputs outputs stateVersion; };
in
{
  inherit (helpers) mkHome mkHost forAllSystems;
  inherit hosts;
  inherit (hosts) mkHostFromToml mkHomeFromToml;
}
