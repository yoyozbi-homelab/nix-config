{ config, inputs, platform , ... }:
let
  stateDir = "/var/lib/pangolin";
  secretsFile = ./pangolin-secrets.yml;
  baseDomain = "yohanzbinden.ch";
  pangolinDomain = "pangolin.${baseDomain}";
  email = "yohan@${baseDomain}";
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
  ];

  sops = {
    secrets = {
      pangolin-server-secret.sopsFile = secretsFile;
    };
  };

  virtualisation.arion.projects.pangolin.settings = {
    networks.pangolin = {
      name = "pangolin";
      driver = "bridge";
      ipam.config = [
        {
          subnet = "172.31.0.0/24";
          gateway = "172.32.0.1";

        }
      ];
    };

    services = {
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
          interval = "10s";
          timeout = "10s";
          retries = 15;
        };
      };

      gerbil.service = {
        image = "docker.io/fosrl/gerbil:1.5.0";
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
      };
    };
  };
}
