# based on https://github.com/TUM-DSE/doctor-cluster-config/blob/master/modules/hosts.nix
# Options-only module: declares networking.yoyozbi.hosts / currentHost.
# Data is injected by mkHostFromToml via { networking.yoyozbi.hosts = lib.hosts.network; }.
{
  lib,
  config,
  hostname,
  desktop,
  ...
}:
let
  traefikOptions = lib.types.submodule {
    options = {
      enabled = lib.mkOption { type = lib.types.bool; default = false; };
      dashboardUrl = lib.mkOption { type = lib.types.str; default = "traefik.${hostname}.local"; };
    };
  };
  longhornOptions = lib.types.submodule {
    options = {
      enabled = lib.mkOption { type = lib.types.bool; default = false; };
      dashboardUrl = lib.mkOption { type = lib.types.str; default = "longhorn.${hostname}.local"; };
    };
  };
  argocdOptions = lib.types.submodule {
    options = {
      enabled = lib.mkOption { type = lib.types.bool; default = false; };
      dashboardUrl = lib.mkOption { type = lib.types.str; default = "argocd.${hostname}.local"; };
    };
  };
  fluxOptions = lib.types.submodule {
    options = {
      enabled = lib.mkOption { type = lib.types.bool; default = false; };
      dashboardUrl = lib.mkOption { type = lib.types.str; default = "flux.${hostname}.local"; };
    };
  };
  portainerOptions = lib.types.submodule {
    options = {
      enabled = lib.mkOption { type = lib.types.bool; default = false; };
      dashboardUrl = lib.mkOption { type = lib.types.str; default = "portainer.${hostname}.local"; };
    };
  };
  hostOptions = with lib; {
    internalIp = mkOption { type = types.str; };
    externalIp  = mkOption { type = types.str; };
    mac         = mkOption { type = types.nullOr types.str; default = null; };
    rancher     = mkOption { type = types.bool; default = false; };
    "traefik-dashboard" = mkOption { type = types.nullOr traefikOptions; default = null; };
    portainer   = mkOption { type = types.nullOr portainerOptions; default = null; };
    argocd      = mkOption { type = types.nullOr argocdOptions; default = null; };
    flux        = mkOption { type = types.nullOr fluxOptions; default = null; };
    longhorn    = mkOption { type = types.nullOr longhornOptions; default = null; };
  };
in
{
  options = with lib; {
    networking.yoyozbi.hosts = mkOption {
      type = with types; attrsOf (submodule [ { options = hostOptions; } ]);
      default = {};
      description = "Cluster hosts keyed by hostname";
    };
    networking.yoyozbi.currentHost = mkOption {
      type = with types; submodule [ { options = hostOptions; } ];
      default = config.networking.yoyozbi.hosts.${hostname};
      description = "The host described by this configuration";
    };
  };
  config.warnings = lib.optional (
    !(config.networking.yoyozbi.hosts ? ${hostname}) && desktop == null
  ) "No network config for ${hostname} in hosts TOML — add a [network] section to hosts/${hostname}/host.toml";
}
