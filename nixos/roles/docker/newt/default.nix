# This requires sops secrets named newt-endpoint, newt-id and newt-secret !
{ config, inputs, ... }:
{
  imports = [
    inputs.arion.nixosModules.arion
  ];

  assertions =
    map
      (name: {
        assertion = builtins.hasAttr name config.sops.secrets;
        message = ''
          The newt role requires a SOPS secret named `${name}`.
          Declare it on the host, e.g. in hosts/<host>/hardware.nix:
            sops.secrets.${name} = { };
        '';
      })
      [
        "newt-endpoint"
        "newt-id"
        "newt-secret"
      ];

  # Newt reads its credentials from a JSON config file so they never land in the
  # container environment (and therefore never show up in `docker inspect`).
  sops.templates."newt-config.json" = {
    content = builtins.toJSON {
      endpoint = config.sops.placeholder.newt-endpoint or "";
      id = config.sops.placeholder.newt-id or "";
      secret = config.sops.placeholder.newt-secret or "";
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
        "${config.sops.templates."newt-config.json".path}:/config/config.json:ro"
      ];
      environment = {
        CONFIG_FILE = "/config/config.json";
        HEALTH_FILE = "/tmp/healthy";
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
}
