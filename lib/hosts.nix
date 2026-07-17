# TOML host loader — Phase 1 of the restructure described in
# .claude/plans/toml-host-restructure.plan.md
#
# Every directory under ../hosts containing a host.toml defines one machine.
# This file parses, validates and normalizes those TOMLs. Pure eval
# (builtins.fromTOML on in-repo files), no IFD.
#
# As of Phase 1 nothing consumes this data except the flake `checks` output;
# flake outputs are still generated from the legacy attrsets in flake.nix.
# Phases 2-5 (see the plan) move the modules into nixos/roles + home/ and then
# generate nixosConfigurations / homeConfigurations / the cachix-deploy spec
# from `nixos`, `home` and `deploy` below, using the resolution helpers at the
# bottom of this file.
#
# host.toml schema — [host] table:
#   username       str, REQUIRED — primary user of the machine
#   platform       str, default "x86_64-linux"
#   desktop        str, optional — desktop selector (kde/gnome/noctalia/...);
#                  absent = server (and thus a cachix-deploy agent)
#   nixos          bool, default true — false = home-manager-only host
#   home           bool, default false — generate standalone
#                  homeConfigurations."<username>@<hostname>"
#   build-home     bool, default false — embed home-manager in the NixOS build
#   state-version  str, default = flake-wide stateVersion
#   roles          [str] — NixOS role modules, resolved (from Phase 3) against
#                  nixos/roles/ as <name>.nix or <name>/default.nix; names may
#                  contain "/" for nested roles (e.g. "desktop/hyprland")
#   home-roles     [str] — same, against home/roles/
#   packages       [str] — extra environment.systemPackages by attr path;
#                  dots traverse, so "unstable.discord" works via the overlay
#   home-packages  [str] — same for home.packages
#   hardware       [str] — inputs.nixos-hardware.nixosModules.<name> entries
#   overlays       [str] — extra overlay names from outputs.overlays (the
#                  additions/modifications/unstable-packages trio is always on)
#
# [network] table (optional, servers only): passed through VERBATIM as
# networking.yoyozbi.hosts.<hostname>, so keys must match the option names
# declared in hosts.nix (internalIp, externalIp, mac, rancher, and the
# traefik-dashboard/portainer/argocd/flux/longhorn sub-tables with
# {enabled, dashboardUrl}). Zero-mapping by design: the options module keeps
# working unchanged when its data moves here in Phase 4.
{
  inputs,
  outputs,
  stateVersion,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;

  hostsDir = ../hosts;

  knownPlatforms = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  # key -> { type, default? } ; a key without a default is required
  hostSchema = {
    username = {
      type = "string";
    };
    platform = {
      type = "string";
      default = "x86_64-linux";
    };
    desktop = {
      type = "string";
      default = null;
    };
    nixos = {
      type = "bool";
      default = true;
    };
    home = {
      type = "bool";
      default = false;
    };
    build-home = {
      type = "bool";
      default = false;
    };
    state-version = {
      type = "string";
      default = stateVersion;
    };
    roles = {
      type = "listOfString";
      default = [ ];
    };
    home-roles = {
      type = "listOfString";
      default = [ ];
    };
    packages = {
      type = "listOfString";
      default = [ ];
    };
    home-packages = {
      type = "listOfString";
      default = [ ];
    };
    hardware = {
      type = "listOfString";
      default = [ ];
    };
    overlays = {
      type = "listOfString";
      default = [ ];
    };
  };

  typeChecks = {
    string = builtins.isString;
    bool = builtins.isBool;
    listOfString = v: builtins.isList v && builtins.all builtins.isString v;
  };

  loadHost =
    name:
    let
      err = msg: throw "hosts/${name}/host.toml: ${msg}";
      raw = builtins.fromTOML (builtins.readFile (hostsDir + "/${name}/host.toml"));

      unknownSections = lib.subtractLists [ "host" "network" ] (builtins.attrNames raw);
      hostSection = raw.host or (err "missing [host] section");
      unknownKeys = lib.subtractLists (builtins.attrNames hostSchema) (builtins.attrNames hostSection);

      getKey =
        key: spec:
        if hostSection ? ${key} then
          (
            if typeChecks.${spec.type} hostSection.${key} then
              hostSection.${key}
            else
              err "key '${key}' must be a ${spec.type}"
          )
        else
          spec.default or (err "missing required key '${key}'");

      checked =
        if unknownSections != [ ] then
          err "unknown section(s): ${toString unknownSections} (only [host] and [network] are allowed)"
        else if unknownKeys != [ ] then
          err "unknown [host] key(s): ${toString unknownKeys} (known: ${toString (builtins.attrNames hostSchema)})"
        else
          builtins.mapAttrs getKey hostSchema;

      normalized = {
        hostname = name;
        inherit (checked)
          username
          platform
          desktop
          nixos
          home
          roles
          packages
          hardware
          overlays
          ;
        buildHome = checked."build-home";
        stateVersion = checked."state-version";
        homeRoles = checked."home-roles";
        homePackages = checked."home-packages";
        network = raw.network or null;
      };
    in
    if !(builtins.elem normalized.platform knownPlatforms) then
      err "platform '${normalized.platform}' not one of: ${toString knownPlatforms}"
    else if !normalized.nixos && !normalized.home then
      err "nixos = false requires home = true (host would define nothing)"
    else if normalized.buildHome && !normalized.nixos then
      err "build-home = true requires nixos = true"
    else
      normalized;

  dirEntries = builtins.readDir hostsDir;
  hostNames = builtins.filter (
    name: dirEntries.${name} == "directory" && builtins.pathExists (hostsDir + "/${name}/host.toml")
  ) (builtins.attrNames dirEntries);

  all = lib.genAttrs hostNames loadHost;

  roleModule =
    rolesDir: role:
    if builtins.pathExists (rolesDir + "/${role}.nix") then
      rolesDir + "/${role}.nix"
    else if builtins.pathExists (rolesDir + "/${role}/default.nix") then
      rolesDir + "/${role}"
    else
      throw "role '${role}' not found under ${toString rolesDir} (expected ${role}.nix or ${role}/default.nix)";

  hardwareModule =
    name:
    inputs.nixos-hardware.nixosModules.${name}
      or (throw "'${name}' is not an inputs.nixos-hardware.nixosModules attribute");

  # Network data derived from TOML [network] sections, keyed by hostname.
  # Passed as an inline module to mkHostFromToml so networking.yoyozbi.hosts
  # is always populated without needing to thread it through specialArgs.
  networkData = lib.mapAttrs (_: h: h.network) (lib.filterAttrs (_: h: h.network != null) all);

in
{
  inherit all;

  nixos = lib.filterAttrs (_: h: h.nixos) all;
  home = lib.filterAttrs (_: h: h.home) all;
  deploy = lib.filterAttrs (_: h: h.nixos && h.desktop == null) all;
  network = networkData;

  # --- Resolution helpers ---------------------------------------------------

  inherit roleModule hardwareModule;

  resolvePackage =
    pkgs: path:
    lib.attrByPath (lib.splitString "." path) (throw "package '${path}' not found in pkgs") pkgs;

  overlay =
    name: outputs.overlays.${name} or (throw "'${name}' is not an outputs.overlays attribute");

  # --- TOML-driven generators (Phase 3+) -----------------------------------

  mkHostFromToml =
    data:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs outputs stateVersion;
        inherit (data)
          hostname
          username
          desktop
          platform
          ;
      };
      modules = [
        ../nixos/core
        {
          networking.hostName = data.hostname;
          nixpkgs.hostPlatform = lib.mkDefault data.platform;
          networking.yoyozbi.hosts = networkData;
        }
        ../nixos/users/root
      ]
      ++ lib.optional (builtins.pathExists (../hosts + "/${data.hostname}/hardware.nix")) (
        ../hosts + "/${data.hostname}/hardware.nix"
      )
      ++ lib.optional (builtins.pathExists (../nixos/users + "/${data.username}")) (
        ../nixos/users + "/${data.username}"
      )
      ++ map hardwareModule data.hardware
      ++ map (roleModule ../nixos/roles) data.roles
      ++ lib.optionals (data.desktop != null) [
        ../nixos/roles/desktop
        (../nixos/roles/desktop + "/${data.desktop}.nix")
      ]
      ++ lib.optionals data.buildHome [
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = false;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit inputs outputs stateVersion;
              inherit (data)
                hostname
                username
                desktop
                platform
                ;
            };
            users.${data.username} = import ../home;
          };
        }
      ];
    };

  mkHomeFromToml =
    data:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${data.platform};
      extraSpecialArgs = {
        inherit inputs outputs stateVersion;
        inherit (data)
          hostname
          username
          desktop
          platform
          ;
      };
      modules = [ ../home ];
    };
}
