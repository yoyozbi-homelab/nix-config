# Pangolin machine client (pangolin-cli `up client`), so this host can reach
# private resources behind other Pangolin sites (e.g. rp, the ocr1 cluster).
#
# Credentials come from an env file ({PANGOLIN_ENDPOINT,PANGOLIN_CLIENT_ID,
# PANGOLIN_CLIENT_SECRET}) that is sourced inside the container, so they never
# land in the container environment (and therefore never in `docker inspect`).
# The file comes from either:
#   - SOPS secrets named pangolin-client-endpoint, pangolin-client-id and
#     pangolin-client-secret, rendered here, or
#   - yoyozbi.pangolinClient.envFile, rendered by another module.
#
# The client runs with host networking, as upstream documents: its WireGuard
# interface and the routes to private resources land on the host, so any
# container on a regular bridge network reaches them through the host. Aliases
# are answered by the client's DNS proxy on the first address of the org's
# utility subnet (yoyozbi.pangolinClient.dnsProxy); point a container's `dns` at
# it to resolve them. The host's own DNS is left alone (OVERRIDE_DNS=false).
{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.yoyozbi.pangolinClient;

  sopsSecretNames = [
    "pangolin-client-endpoint"
    "pangolin-client-id"
    "pangolin-client-secret"
  ];
  hasSopsCredentials = lib.all (name: config.sops.secrets ? ${name}) sopsSecretNames;
in
{
  imports = [
    inputs.arion.nixosModules.arion
  ];

  options.yoyozbi.pangolinClient = with lib; {
    envFile = mkOption {
      type = types.nullOr types.str;
      default = if hasSopsCredentials then config.sops.templates."pangolin-client.env".path else null;
      defaultText = literalExpression ''config.sops.templates."pangolin-client.env".path'';
      description = "Shell env file setting PANGOLIN_ENDPOINT, PANGOLIN_CLIENT_ID and PANGOLIN_CLIENT_SECRET.";
    };

    dnsProxy = mkOption {
      type = types.str;
      default = "100.96.128.1";
      description = ''
        Address of the client's DNS proxy, which answers Pangolin aliases: the
        first address of the org's utility subnet (100.96.128.0/24 by default).
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.envFile != null;
        message = ''
          The pangolin-client role needs credentials. Either declare the SOPS
          secrets ${lib.concatStringsSep ", " sopsSecretNames} on the host, e.g.
          in hosts/<host>/hardware.nix:
            sops.secrets.pangolin-client-id = { };
          or point yoyozbi.pangolinClient.envFile at a file you provide.
        '';
      }
    ];

    # Single-quoted so the shell takes the values literally; they must not
    # contain a single quote themselves.
    sops.templates."pangolin-client.env" = lib.mkIf hasSopsCredentials {
      content = ''
        PANGOLIN_ENDPOINT='${config.sops.placeholder.pangolin-client-endpoint}'
        PANGOLIN_CLIENT_ID='${config.sops.placeholder.pangolin-client-id}'
        PANGOLIN_CLIENT_SECRET='${config.sops.placeholder.pangolin-client-secret}'
      '';
      restartUnits = [ "arion-pangolin-client.service" ];
    };

    virtualisation.arion.backend = "docker";

    virtualisation.arion.projects.pangolin-client.settings = {
      services.pangolin-cli.service = {
        image = "docker.io/fosrl/pangolin-cli:0.21.0";
        container_name = "pangolin-cli";
        restart = "unless-stopped";
        network_mode = "host";
        capabilities.NET_ADMIN = true;
        devices = [ "/dev/net/tun:/dev/net/tun" ];
        volumes = [
          "${cfg.envFile}:/run/secrets/pangolin-client.env:ro"
        ];
        # The image's entrypoint only takes credentials from the environment;
        # bypass it and export them from the mounted file instead.
        entrypoint = "/bin/sh";
        command = [
          "-c"
          "set -a && . /run/secrets/pangolin-client.env && set +a && exec pangolin-cli up client --attach"
        ];
        environment = {
          OVERRIDE_DNS = "false";
        };
      };
    };
  };
}
