# Cloudflare tunnel connector, remotely managed: ingress rules live in the
# Cloudflare dashboard, only the tunnel token is needed here.
#
# This requires a sops secret named cloudflared-token !
{ config, inputs, ... }:
let
  # The image is distroless and runs as `nonroot`.
  cloudflaredUid = 65532;
in
{
  imports = [
    inputs.arion.nixosModules.arion
  ];

  assertions = [
    {
      assertion = config.sops.secrets ? cloudflared-token;
      message = ''
        The cloudflared role requires a SOPS secret named `cloudflared-token`.
        Declare it on the host, e.g. in hosts/<host>/hardware.nix:
          sops.secrets.cloudflared-token = { };
      '';
    }
  ];

  sops.secrets.cloudflared-token = {
    uid = cloudflaredUid;
    mode = "0400";
    restartUnits = [ "arion-cloudflared.service" ];
  };

  virtualisation.arion.backend = "docker";

  virtualisation.arion.projects.cloudflared.settings = {
    services.cloudflared.service = {
      image = "docker.io/cloudflare/cloudflared:2026.9.1";
      container_name = "cloudflared";
      restart = "unless-stopped";
      # The image entrypoint is already `cloudflared --no-autoupdate`.
      command = [
        "tunnel"
        "run"
      ];
      volumes = [
        "${config.sops.secrets.cloudflared-token.path}:/run/secrets/cloudflared-token:ro"
      ];
      # Read from a file so the token never shows up in `docker inspect`.
      environment.TUNNEL_TOKEN_FILE = "/run/secrets/cloudflared-token";
    };
  };
}
