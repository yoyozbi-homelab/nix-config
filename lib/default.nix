{
  inputs,
  outputs,
  stateVersion,
  ...
}:
let
  hosts = import ./hosts.nix { inherit inputs outputs stateVersion; };
in
{
  inherit hosts;
  inherit (hosts) mkHostFromToml mkHomeFromToml;
}
