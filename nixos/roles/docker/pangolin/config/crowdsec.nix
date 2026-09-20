{
  config,
  pkgs,
  stateDir,
  ...
}:
let
  crowdsecDir = "${stateDir}/crowdsec";

  acquisTraefik = pkgs.writeText "crowdsec-acquis-traefik.yaml" ''
    poll_without_inotify: false
    filenames:
      - /var/log/traefik/access.log
    labels:
      type: traefik
  '';

  acquisAppsec = pkgs.writeText "crowdsec-acquis-appsec.yaml" ''
    listen_addr: 0.0.0.0:7422
    appsec_config: crowdsecurity/appsec-default
    name: traefik-appsec
    source: appsec
    labels:
      type: appsec
  '';
in
{
  # The crowdsec entrypoint registers a bouncer named `traefik` with this key
  # on startup, so the traefik plugin authenticates without a manual
  # `cscli bouncers add`.
  sops.templates."crowdsec.env".content = ''
    BOUNCER_KEY_traefik=${config.sops.placeholder.crowdsec-bouncer-key or ""}
  '';

  sops.templates."crowdsec.env".restartUnits = [ "arion-pangolin.service" ];

  systemd.tmpfiles.rules = [
    "d ${crowdsecDir} 0750 root root -"
    "d ${crowdsecDir}/config 0750 root root -"
    "d ${crowdsecDir}/data 0750 root root -"
  ];

  virtualisation.arion.projects.pangolin.settings.services.crowdsec.service = {
    image = "docker.io/crowdsecurity/crowdsec:v1.8.1";
    container_name = "crowdsec";
    restart = "unless-stopped";
    environment = {
      COLLECTIONS = "crowdsecurity/traefik crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-generic-rules";
      PARSERS = "crowdsecurity/whitelists";
    };
    env_file = [ config.sops.templates."crowdsec.env".path ];
    volumes = [
      "${crowdsecDir}/config:/etc/crowdsec:rw"
      "${crowdsecDir}/data:/var/lib/crowdsec/data:rw"
      "${acquisTraefik}:/etc/crowdsec/acquis.d/traefik.yaml:ro"
      "${acquisAppsec}:/etc/crowdsec/acquis.d/appsec.yaml:ro"
      "${stateDir}/config/traefik/logs:/var/log/traefik:ro"
    ];
    # LAPI (8080) and AppSec (7422) are only reached by traefik over the
    # compose network; nothing is published on the host.
    healthcheck = {
      test = [
        "CMD"
        "cscli"
        "lapi"
        "status"
      ];
      interval = "10s";
      timeout = "5s";
      retries = 5;
      # First start downloads the hub collections before LAPI comes up.
      start_period = "60s";
    };
  };
}
