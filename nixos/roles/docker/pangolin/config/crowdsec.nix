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

  # See the `limits` helper in ../default.nix for why these exist. crowdsec is
  # analysis, not the data path, so it gets the lowest share on a contended box.
  virtualisation.arion.projects.pangolin.settings.services.crowdsec.out.service = {
    cpus = "0.40";
    cpu_shares = 256;
    mem_limit = "192m";
    mem_reservation = "64m";
    pids_limit = 256;
  };

  virtualisation.arion.projects.pangolin.settings.services.crowdsec.service = {
    image = "docker.io/crowdsecurity/crowdsec:v1.8.1";
    container_name = "crowdsec";
    restart = "unless-stopped";
    environment = {
      # appsec-generic-rules is deliberately absent: its broad pattern matching
      # was a large share of the crowdsec + traefik CPU on tiny1, which runs at
      # 70%+ steal. virtual-patching keeps the targeted CVE rules, and the
      # traefik collection keeps log-based IP banning, both of which are cheap.
      COLLECTIONS = "crowdsecurity/traefik crowdsecurity/appsec-virtual-patching";
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
      # cscli is a ~16 MB Go binary and every probe spawns one, so this ran at
      # 10s intervals purely to feed the memory pressure it was competing with.
      interval = "30s";
      timeout = "5s";
      retries = 5;
      # First start downloads the hub collections before LAPI comes up.
      start_period = "60s";
    };
  };
}
