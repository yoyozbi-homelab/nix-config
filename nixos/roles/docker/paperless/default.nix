# paperless-ngx with its own Postgres and Valkey.
#
# yoyozbi.paperless.secretKeyFile must be set: the key signs sessions, so it
# has to come from somewhere stable (SOPS, bitwarden-secrets, ...). The database
# password never leaves the host, so it is generated on first start instead.
{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.yoyozbi.paperless;
  httpPort = 8000;

  # paperless drops to this uid (USERMAP_UID, image default); the official
  # postgres image runs as 999.
  paperlessUid = 1000;
  postgresUid = 999;

  dbPasswordFile = "${cfg.dataDir}/db-password";
in
{
  imports = [
    inputs.arion.nixosModules.arion
  ];

  options.yoyozbi.paperless = with lib; {
    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/paperless";
      description = "Holds paperless' data, media, consume and export dirs, and the Postgres cluster.";
    };

    secretKeyFile = mkOption {
      type = types.str;
      description = "File containing PAPERLESS_SECRET_KEY (no trailing newline).";
    };

    url = mkOption {
      type = types.str;
      default = "https://paperless.yohanzbinden.ch";
      description = "Public URL, used by paperless for CSRF and allowed hosts.";
    };
  };

  config = {
    virtualisation.arion.backend = "docker";

    networking.firewall.allowedTCPPorts = [ httpPort ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
      "d ${cfg.dataDir}/data 0750 ${toString paperlessUid} ${toString paperlessUid} -"
      "d ${cfg.dataDir}/media 0750 ${toString paperlessUid} ${toString paperlessUid} -"
      "d ${cfg.dataDir}/consume 0750 ${toString paperlessUid} ${toString paperlessUid} -"
      "d ${cfg.dataDir}/export 0750 ${toString paperlessUid} ${toString paperlessUid} -"
      "d ${cfg.dataDir}/postgres 0700 ${toString postgresUid} ${toString postgresUid} -"
    ];

    systemd.services.arion-paperless = {
      # Don't start against an empty mount point if dataDir is on a disk that
      # failed to mount; everything would silently land on the root fs.
      unitConfig.RequiresMountsFor = [ cfg.dataDir ];

      # Postgres only reads its password when initialising the cluster, so it
      # has to stay stable: generate it once and keep it next to the data.
      # Owned by postgres because its entrypoint reads the file after dropping
      # root; paperless reads it while still root.
      preStart = ''
        if [ ! -s ${dbPasswordFile} ]; then
          (umask 077 && head -c 36 /dev/urandom | base64 -w 0 | tr '+/' '-_' > ${dbPasswordFile})
        fi
        chown ${toString postgresUid} ${dbPasswordFile}
        chmod 0400 ${dbPasswordFile}
      '';
    };

    virtualisation.arion.projects.paperless.settings = {
      services = {
        broker.service = {
          image = "docker.io/valkey/valkey:8.1.10-alpine";
          container_name = "paperless-valkey";
          restart = "unless-stopped";
          # Holds the celery queue and channel layer, which rebuild themselves:
          # no persistence.
          command = [
            "--save"
            ""
            "--appendonly"
            "no"
          ];
        };

        db.service = {
          image = "docker.io/library/postgres:18.6";
          container_name = "paperless-postgres";
          restart = "unless-stopped";
          volumes = [
            # Postgres 18+ keeps PGDATA in a major-version subdirectory of this.
            "${cfg.dataDir}/postgres:/var/lib/postgresql:rw"
            "${dbPasswordFile}:/run/secrets/db-password:ro"
          ];
          environment = {
            POSTGRES_DB = "paperless";
            POSTGRES_USER = "paperless";
            POSTGRES_PASSWORD_FILE = "/run/secrets/db-password";
          };
          healthcheck = {
            test = [
              "CMD-SHELL"
              "pg_isready -U paperless -d paperless"
            ];
            interval = "10s";
            timeout = "5s";
            retries = 5;
          };
        };

        webserver.service = {
          image = "ghcr.io/paperless-ngx/paperless-ngx:3.2.0";
          container_name = "paperless";
          restart = "unless-stopped";
          depends_on = [
            "broker"
            "db"
          ];
          ports = [
            "${toString httpPort}:8000"
          ];
          volumes = [
            "${cfg.dataDir}/data:/usr/src/paperless/data:rw"
            "${cfg.dataDir}/media:/usr/src/paperless/media:rw"
            "${cfg.dataDir}/consume:/usr/src/paperless/consume:rw"
            "${cfg.dataDir}/export:/usr/src/paperless/export:rw"
            "${cfg.secretKeyFile}:/run/secrets/secret-key:ro"
            "${dbPasswordFile}:/run/secrets/db-password:ro"
          ];
          environment = {
            USERMAP_UID = toString paperlessUid;
            USERMAP_GID = toString paperlessUid;
            PAPERLESS_URL = cfg.url;
            PAPERLESS_TIME_ZONE = "Europe/Zurich";
            PAPERLESS_REDIS = "redis://broker:6379";
            PAPERLESS_DBENGINE = "postgresql";
            PAPERLESS_DBHOST = "db";
            PAPERLESS_DBNAME = "paperless";
            PAPERLESS_DBUSER = "paperless";
            # The image's s6 init resolves every PAPERLESS_*_FILE into the
            # matching variable, so neither secret is in `docker inspect`.
            PAPERLESS_DBPASS_FILE = "/run/secrets/db-password";
            PAPERLESS_SECRET_KEY_FILE = "/run/secrets/secret-key";
            # Requests arrive through Pangolin/newt. Without this allauth cannot
            # determine the client IP and returns 403 on login.
            PAPERLESS_ALLAUTH_TRUSTED_CLIENT_IP_HEADER = "X-Forwarded-For";
          };
        };
      };
    };
  };
}
