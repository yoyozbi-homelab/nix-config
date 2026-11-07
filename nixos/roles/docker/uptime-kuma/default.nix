# Uptime Kuma, configured declaratively through AutoKuma static monitors.
#
# Every entry of yoyozbi.uptimeKuma.entities becomes one AutoKuma static file,
# whose name (the attribute name) is the AutoKuma ID: use it in `parent_name`
# and `notification_name_list`. Entities holding secrets go through
# yoyozbi.uptimeKuma.secretEntities instead (a path to a JSON file rendered at
# runtime, e.g. a SOPS template). AutoKuma deletes entities that disappear from
# here, so this is the full list; monitors created by hand in the UI are left
# alone. See https://autokuma.bigboot.dev/latest/entity-types/ for the fields.
#
# Uptime Kuma can't create its admin user from config. After the first deploy,
# open it through `ssh -L 3001:127.0.0.1:3001 <host>` and create the user
# `yoyozbi.uptimeKuma.username` with the password in the SOPS secret
# `uptime-kuma-password`, before
# exposing it anywhere: until then anyone reaching it can claim it.
#
# The UI only listens on 127.0.0.1:3001; expose it with cloudflared in host
# network mode (yoyozbi.cloudflared.hostNetwork) or an SSH tunnel.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.yoyozbi.uptimeKuma;
  httpPort = 3001;

  entityFiles =
    lib.mapAttrs (
      id: entity: pkgs.writeText "autokuma-${id}.json" (builtins.toJSON entity)
    ) cfg.entities
    // cfg.secretEntities;

  # One bind mount per file rather than a store directory: AutoKuma doesn't
  # follow symlinks by default, and a store path has nothing else in it to
  # leak, so this keeps the container's view to exactly these files.
  entityMounts = lib.mapAttrsToList (id: file: "${file}:/static/${id}.json:ro") entityFiles;
in
{
  imports = [
    inputs.arion.nixosModules.arion
  ];

  options.yoyozbi.uptimeKuma = with lib; {
    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/uptime-kuma";
      description = "Holds Uptime Kuma's SQLite database and AutoKuma's state.";
    };

    username = mkOption {
      type = types.str;
      default = "admin";
      description = "Uptime Kuma admin user AutoKuma logs in as.";
    };

    dns = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "100.96.128.1"
        "1.1.1.1"
      ];
      description = ''
        DNS servers for the Uptime Kuma container, tried in order. Empty keeps
        Docker's default (the host's resolvers).
      '';
    };

    entities = mkOption {
      type = types.attrsOf (types.attrsOf types.anything);
      default = { };
      description = "AutoKuma static entities (monitors, groups, notifications) by AutoKuma ID.";
    };

    secretEntities = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "AutoKuma static entities that contain secrets, as paths to JSON files, by AutoKuma ID.";
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.mutuallyExclusive (lib.attrNames cfg.entities) (lib.attrNames cfg.secretEntities);
        message = "yoyozbi.uptimeKuma.entities and secretEntities must not share an AutoKuma ID.";
      }
    ];

    # The admin password AutoKuma logs in with; it must match the user
    # created by hand in the UI (see the top of this file).
    sops.secrets.uptime-kuma-password.restartUnits = [ "arion-uptime-kuma.service" ];

    virtualisation.arion.backend = "docker";

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
      "d ${cfg.dataDir}/kuma 0750 root root -"
      "d ${cfg.dataDir}/autokuma 0750 root root -"
    ];

    systemd.services.arion-uptime-kuma.unitConfig.RequiresMountsFor = [ cfg.dataDir ];

    virtualisation.arion.projects.uptime-kuma.settings = {
      services = {
        uptime-kuma.service = {
          image = "docker.io/louislam/uptime-kuma:2.5.9-slim";
          container_name = "uptime-kuma";
          restart = "unless-stopped";
          ports = [ "127.0.0.1:${toString httpPort}:3001" ];
          inherit (cfg) dns;
          volumes = [
            "${cfg.dataDir}/kuma:/app/data:rw"
          ];
          environment = {
            # Skips the database wizard on first start.
            UPTIME_KUMA_DB_TYPE = "sqlite";
          };
          # The image ships its own HEALTHCHECK, which autokuma waits on.
        };

        autokuma.service = {
          image = "ghcr.io/bigboot/autokuma:2.1.0-rc.2";
          container_name = "autokuma";
          restart = "unless-stopped";
          depends_on = {
            uptime-kuma = {
              condition = "service_healthy";
            };
          };
          volumes = [
            "${cfg.dataDir}/autokuma:/data:rw"
            "${config.sops.secrets.uptime-kuma-password.path}:/run/secrets/kuma-password:ro"
          ]
          ++ entityMounts;
          environment = {
            AUTOKUMA__KUMA__URL = "http://uptime-kuma:3001";
            AUTOKUMA__KUMA__USERNAME = cfg.username;
            # `@/` makes AutoKuma read the value from that file, so the
            # password is not in `docker inspect`.
            AUTOKUMA__KUMA__PASSWORD = "@/run/secrets/kuma-password";
            AUTOKUMA__DATA_PATH = "/data";
            AUTOKUMA__STATIC_MONITORS = "/static";
            AUTOKUMA__DOCKER__ENABLED = "false";
            AUTOKUMA__ON_DELETE = "delete";
          };
        };
      };
    };
  };
}
