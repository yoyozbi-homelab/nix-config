# rp's docker stacks (roles docker/newt and docker/paperless), their backup
# (role backup) and the secrets they pull from Bitwarden Secrets Manager.
{ config, lib, ... }:
let
  bws = config.yoyozbi.bitwardenSecrets;
  paperlessDir = config.yoyozbi.paperless.dataDir;
  docker = lib.getExe' config.virtualisation.docker.package "docker";

  # Both stacks read files written by bitwarden-secrets.service; Requires= also
  # restarts them whenever it re-fetches.
  needsBitwardenSecrets = {
    requires = [ "bitwarden-secrets.service" ];
    after = [ "bitwarden-secrets.service" ];
  };
in
{
  yoyozbi = {
    bitwardenSecrets = {
      secrets = {
        newt-endpoint.id = "e3444699-27f7-436a-b954-b4b5009b5eed";
        newt-id.id = "2d0ced07-1c72-4840-bda3-b4b5009b749e";
        newt-secret.id = "206f0375-9535-4132-ab5d-b4b5009b84e5";
        paperless-secret-key.id = "fd4a6fa7-1ba2-4315-bea2-b4b500b73eb8";
        backup-target-url.id = "f1dd8764-7b77-4f93-a6e9-b4ca00da41bb";
        backup-webdav-password.id = "9d7f52ca-d81a-4412-9a59-b4ca00db28e8";
        backup-passphrase.id = "ada96254-42cf-428b-a6e1-b4ca00daa975";
        backup-ntfy-url.id = "820308d8-9e28-4a49-921b-b4ca00dea4db";
      };

      # Single-quoted so systemd takes the values literally; they must not
      # contain a single quote themselves.
      templates."backup.env".content = ''
        BACKUP_TARGET_URL='${bws.placeholder.backup-target-url}'
        BACKEND_PASSWORD='${bws.placeholder.backup-webdav-password}'
        PASSPHRASE='${bws.placeholder.backup-passphrase}'
        NTFY_URL='${bws.placeholder.backup-ntfy-url}'
      '';

      templates."newt-config.json".content = builtins.toJSON {
        endpoint = bws.placeholder.newt-endpoint;
        id = bws.placeholder.newt-id;
        secret = bws.placeholder.newt-secret;
      };
    };

    newt = {
      configFile = bws.templates."newt-config.json".path;
      acceptClients = true;
    };

    paperless = {
      dataDir = "/mnt/data/paperless";
      secretKeyFile = bws.secrets.paperless-secret-key.path;
    };

    # Postgres' files are skipped: copied while it runs they are not consistent.
    # A plain-SQL dump is, and diffs well between incrementals.
    backup = {
      environmentFile = bws.templates."backup.env".path;
      paths = [
        "${paperlessDir}/data"
        "${paperlessDir}/media"
        "${paperlessDir}/consume"
        "${paperlessDir}/db-dump"
      ];
      preBackup = ''
        ${docker} exec paperless-postgres pg_dump -U paperless -d paperless \
          > ${paperlessDir}/db-dump/paperless.sql.tmp
        mv ${paperlessDir}/db-dump/paperless.sql.tmp ${paperlessDir}/db-dump/paperless.sql
      '';
    };
  };

  systemd = {
    tmpfiles.rules = [ "d ${paperlessDir}/db-dump 0700 root root -" ];
    services = {

      arion-newt = needsBitwardenSecrets;
      arion-paperless = needsBitwardenSecrets;
      duplicity-backup = needsBitwardenSecrets;
      duplicity-backup-failure-notify = needsBitwardenSecrets;
    };
  };
}
