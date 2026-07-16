{
  inputs,
  outputs,
  stateVersion,
  ...
}:
let
  helpers = import ./helpers.nix { inherit inputs outputs stateVersion; };
in
{
  inherit (helpers) mkHome mkHost forAllSystems;

  # Parsed hosts/*/host.toml data + resolution helpers (see lib/hosts.nix).
  # Phase 1: only consumed by the flake `checks` output.
  hosts = import ./hosts.nix { inherit inputs outputs stateVersion; };
}
