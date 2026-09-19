# Newt reads its credentials from a JSON config file ({ endpoint, id, secret })
# so they never land in the container environment (and therefore never show up
# in `docker inspect`). The file comes from either:
#   - SOPS secrets named newt-endpoint, newt-id and newt-secret, rendered here, or
#   - yoyozbi.newt.configFile, rendered by another module (e.g. bitwarden-secrets).
{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.yoyozbi.newt;

  sopsSecretNames = [
    "newt-endpoint"
    "newt-id"
    "newt-secret"
  ];
  hasSopsCredentials = lib.all (name: config.sops.secrets ? ${name}) sopsSecretNames;
in
{
  imports = [
    inputs.arion.nixosModules.arion
  ];

  options.yoyozbi.newt = with lib; {
    configFile = mkOption {
      type = types.nullOr types.str;
      default = if hasSopsCredentials then config.sops.templates."newt-config.json".path else null;
      defaultText = literalExpression ''config.sops.templates."newt-config.json".path'';
      description = "JSON file holding the newt endpoint, id and secret.";
    };

    acceptClients = mkOption {
      type = types.bool;
      default = false;
      description = "Accept Pangolin client (olm) connections through this site.";
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.configFile != null;
        message = ''
          The newt role needs credentials. Either declare the SOPS secrets
          ${lib.concatStringsSep ", " sopsSecretNames} on the host, e.g. in
          hosts/<host>/hardware.nix:
            sops.secrets.newt-endpoint = { };
          or point yoyozbi.newt.configFile at a JSON file you provide.
        '';
      }
    ];

    sops.templates."newt-config.json" = lib.mkIf hasSopsCredentials {
      content = builtins.toJSON {
        endpoint = config.sops.placeholder.newt-endpoint;
        id = config.sops.placeholder.newt-id;
        secret = config.sops.placeholder.newt-secret;
      };
      restartUnits = [ "arion-newt.service" ];
    };

    virtualisation.arion.backend = "docker";

    virtualisation.arion.projects.newt.settings = {
      services.newt.service = {
        image = "docker.io/fosrl/newt:1.16.0";
        container_name = "newt";
        restart = "unless-stopped";
        volumes = [
          "${cfg.configFile}:/config/config.json:ro"
        ];
        environment = {
          CONFIG_FILE = "/config/config.json";
          HEALTH_FILE = "/tmp/healthy";
        }
        // lib.optionalAttrs cfg.acceptClients {
          ACCEPT_CLIENTS = "true";
        };
        # newt writes this file once the tunnel is up and removes it as soon as the
        # keepalive pings start failing, so this tracks tunnel health, not liveness.
        healthcheck = {
          test = [
            "CMD-SHELL"
            "[ -f /tmp/healthy ]"
          ];
          interval = "30s";
          timeout = "5s";
          start_period = "30s";
          retries = 3;
        };
      };
    };
  };
}
