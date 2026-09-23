# This requires sops secrets named pangolin-server-secret and crowdsec-bouncer-key !
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  stateDir = "/var/lib/pangolin";
  baseDomain = "yohanzbinden.ch";
  pangolinDomain = "pangolin.${baseDomain}";
  email = "yohan@${baseDomain}";

  # arion's service submodule has no options for compose's resource keys, so
  # they go through the documented `out.service` escape hatch.
  #
  # tiny1 is a 1 OCPU / 1 GB OCI instance that runs at 70%+ CPU steal, so the
  # point of these is less to save resources than to decide who loses when the
  # box is contended: gerbil and traefik carry live proxy traffic and get the
  # highest shares, pangolin (control plane) and crowdsec (log analysis) yield
  # to them. mem_reservation biases kswapd away from the data path, which is
  # the top CPU consumer on this host.
  limits =
    {
      cpus,
      shares,
      mem,
      reserve,
      pids ? 256,
    }:
    {
      inherit cpus;
      cpu_shares = shares;
      mem_limit = mem;
      mem_reservation = reserve;
      pids_limit = pids;
    };
in
{
  imports = [
    inputs.arion.nixosModules.arion
    (import ./config/config.nix {
      inherit
        config
        baseDomain
        pangolinDomain
        email
        ;
    })
    (import ./config/crowdsec.nix { inherit config pkgs stateDir; })
    (import ./config/traefik/traefik_config.nix {
      inherit
        config
        baseDomain
        pangolinDomain
        email
        ;
    })
    (import ./config/traefik/traefik_dynamic_config.nix {
      inherit
        config
        baseDomain
        pangolinDomain
        email
        ;
    })
  ];

  assertions = [
    {
      assertion = config.sops.secrets ? pangolin-server-secret;
      message = ''
        The pangolin role requires a SOPS secret named `pangolin-server-secret`.
        Declare it on the host, e.g. in hosts/<host>/hardware.nix:
          sops.secrets.pangolin-server-secret = { };
      '';
    }
    {
      assertion = config.sops.secrets ? crowdsec-bouncer-key;
      message = ''
        The pangolin role requires a SOPS secret named `crowdsec-bouncer-key`
        (any random string, e.g. `openssl rand -hex 32`).
        Declare it on the host, e.g. in hosts/<host>/hardware.nix:
          sops.secrets.crowdsec-bouncer-key = { };
      '';
    }
  ];

  virtualisation.arion.backend = "docker";

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  networking.firewall.allowedUDPPorts = [
    51820 # WireGuard for the pangolin reverse-proxy P2P connections
    21820 # WireGuard for the pangolin reverse-proxy P2P connections
  ];

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 root root -"
    "d ${stateDir}/config 0750 root root -"
    "d ${stateDir}/config/db 0750 root root -"
    "d ${stateDir}/config/letsencrypt 0750 root root -"
    "d ${stateDir}/config/traefik 0750 root root -"
    "d ${stateDir}/config/traefik/logs 0750 root root -"
  ];

  # Traefik never rotates its access log itself; copytruncate keeps the file
  # handle held by traefik (writer) and crowdsec (reader) valid.
  services.logrotate.settings.traefik-access-log = {
    files = "${stateDir}/config/traefik/logs/access.log";
    frequency = "daily";
    rotate = 7;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    copytruncate = true;
  };

  virtualisation.arion.projects.pangolin.settings = {
    networks.pangolin = {
      name = "pangolin";
      driver = "bridge";
      ipam.config = [
        {
          subnet = "172.31.0.0/24";
          gateway = "172.31.0.1";
        }
      ];
    };

    services = {
      pangolin.out.service = limits {
        cpus = "0.60";
        shares = 512;
        mem = "256m";
        reserve = "128m";
      };
      pangolin.service = {
        image = "docker.io/fosrl/pangolin:ee-1.21.1";
        container_name = "pangolin";
        restart = "unless-stopped";
        volumes = [
          "${config.sops.templates."pangolin-config.yaml".path}:/app/config/config.yaml:ro"
          "${stateDir}/config:/app/config:rw"
        ];
        healthcheck = {
          test = [
            "CMD"
            "curl"
            "-f"
            "http://localhost:3001/api/v1"
          ];
          # Every probe forks a curl; at 10s that was a measurable share of a
          # host where kswapd is already the busiest process. start_period
          # covers the slow first boot that the old retries = 15 paid for.
          interval = "30s";
          timeout = "10s";
          retries = 5;
          start_period = "120s";
        };
      };

      gerbil.out.service = limits {
        cpus = "0.50";
        shares = 1024;
        mem = "96m";
        reserve = "48m";
      };
      gerbil.service = {
        image = "docker.io/fosrl/gerbil:1.5.2";
        container_name = "gerbil";
        restart = "unless-stopped";
        depends_on = {
          pangolin = {
            condition = "service_healthy";
          };
        };
        command = [
          "--reachableAt=http://gerbil:3004"
          "--generateAndSaveKeyTo=/var/config/key"
          "--remoteConfig=http://pangolin:3001/api/v1"
        ];
        volumes = [
          "${config.sops.templates."pangolin-config.yaml".path}:/app/config/config.yaml:ro"
          "${stateDir}/config:/var/config:rw"
        ];
        capabilities = {
          NET_ADMIN = true;
          SYS_MODULE = true;
        };
        ports = [
          "51820:51820/udp"
          "21820:21820/udp"
          "443:443/tcp"
          "443:443/udp" # HTTP 3 traffic (QUIC) for the reverse proxy
          "80:80"
        ];
        # /healthz only proves gerbil's HTTP API is up; traefik depends on it
        # being healthy. The image ships wget but not curl.
        healthcheck = {
          test = [
            "CMD"
            "wget"
            "-qO-"
            "http://127.0.0.1:3004/healthz"
          ];
          interval = "30s";
          timeout = "5s";
          retries = 5;
          start_period = "30s";
        };
      };

      traefik.out.service = limits {
        cpus = "0.75";
        shares = 1024;
        mem = "192m";
        reserve = "96m";
      };
      traefik.service = {
        image = "docker.io/traefik:v3.7";
        container_name = "traefik";
        restart = "unless-stopped";
        network_mode = "service:gerbil";
        depends_on = {
          gerbil = {
            condition = "service_healthy";
          };
          crowdsec = {
            condition = "service_healthy";
          };
        };
        command = [
          "--configFile=/etc/traefik/traefik_config.yml"
        ];
        volumes = [
          "${config.sops.templates."traefik_config.yml".path}:/etc/traefik/traefik_config.yml:ro"
          "${config.sops.templates."traefik_dynamic.yml".path}:/etc/traefik/dynamic.yml:ro"
          "${stateDir}/config/letsencrypt:/letsencrypt:rw"
          "${stateDir}/config/traefik/logs:/var/log/traefik:rw"
        ];
        # Hits /ping on the `web` entrypoint, as enabled in traefik_config.yml.
        healthcheck = {
          test = [
            "CMD"
            "traefik"
            "healthcheck"
            "--configFile=/etc/traefik/traefik_config.yml"
          ];
          interval = "30s";
          timeout = "5s";
          retries = 5;
          start_period = "30s";
        };
      };
    };
  };
}
