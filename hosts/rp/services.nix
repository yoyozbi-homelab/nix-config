# rp's docker stacks (roles docker/newt and docker/paperless) and the secrets
# they pull from Bitwarden Secrets Manager.
{ config, ... }:
let
  bws = config.yoyozbi.bitwardenSecrets;

  # Both stacks read files written by bitwarden-secrets.service; Requires= also
  # restarts them whenever it re-fetches.
  needsBitwardenSecrets = {
    requires = [ "bitwarden-secrets.service" ];
    after = [ "bitwarden-secrets.service" ];
  };
in
{
  yoyozbi.bitwardenSecrets = {
    secrets = {
      newt-endpoint.id = "e3444699-27f7-436a-b954-b4b5009b5eed";
      newt-id.id = "2d0ced07-1c72-4840-bda3-b4b5009b749e";
      newt-secret.id = "206f0375-9535-4132-ab5d-b4b5009b84e5";
      paperless-secret-key.id = "fd4a6fa7-1ba2-4315-bea2-b4b500b73eb8";
    };

    templates."newt-config.json".content = builtins.toJSON {
      endpoint = bws.placeholder.newt-endpoint;
      id = bws.placeholder.newt-id;
      secret = bws.placeholder.newt-secret;
    };
  };

  yoyozbi.newt = {
    configFile = bws.templates."newt-config.json".path;
    acceptClients = true;
  };

  yoyozbi.paperless = {
    dataDir = "/mnt/data/paperless";
    secretKeyFile = bws.secrets.paperless-secret-key.path;
  };

  systemd.services.arion-newt = needsBitwardenSecrets;
  systemd.services.arion-paperless = needsBitwardenSecrets;
}
