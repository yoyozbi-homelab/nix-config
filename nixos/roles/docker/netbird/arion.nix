# NetBird self-hosted stack as an arion (docker-compose) project.
#
# Ported 1:1 from the official getting-started.sh output (Traefik variant,
# proxy + CrowdSec enabled) for netbird.yohanzbinden.ch. Differences from the
# generated compose, all deliberate:
#   * image tags are pinned (Renovate tracks them via renovate.json) instead of :latest
#   * named docker volumes are replaced by bind mounts under /var/lib/netbird
#     (declarative persistence, created by tmpfiles in ../netbird.nix)
#   * the docker network name is forced to "netbird" so Traefik's
#     providers.docker.network and the pinned 172.30.0.10 ingress IP still match
#   * config.yaml / proxy.env carry secrets and are rendered from sops.templates
#     (declared in ../netbird.nix); dashboard.env / traefik-dynamic.yaml are
#     secret-free and baked as store files
{ config, pkgs, ... }:
let
  domain = "netbird.yohanzbinden.ch";
  stateDir = "/var/lib/netbird";

  dashboardEnv = pkgs.writeText "netbird-dashboard.env" ''
    NETBIRD_MGMT_API_ENDPOINT=https://${domain}
    NETBIRD_MGMT_GRPC_API_ENDPOINT=https://${domain}
    AUTH_AUDIENCE=netbird-dashboard
    AUTH_CLIENT_ID=netbird-dashboard
    AUTH_CLIENT_SECRET=
    AUTH_AUTHORITY=https://${domain}/oauth2
    USE_AUTH0=false
    AUTH_SUPPORTED_SCOPES=openid profile email groups
    AUTH_REDIRECT_URI=/nb-auth
    AUTH_SILENT_REDIRECT_URI=/nb-silent-auth
    NGINX_SSL_PORT=443
    LETSENCRYPT_DOMAIN=none
  '';

  # PROXY protocol v2 serversTransport used by the proxy TCP-passthrough router.
  traefikDynamic = pkgs.writeText "traefik-dynamic.yaml" ''
    tcp:
      serversTransports:
        pp-v2:
          proxyProtocol:
            version: 2
  '';
in
{
  virtualisation.arion.projects.netbird.settings = {
    networks.netbird = {
      name = "netbird";
      driver = "bridge";
      ipam.config = [
        {
          subnet = "172.30.0.0/24";
          gateway = "172.30.0.1";
        }
      ];
    };

    services = {
      # Traefik reverse proxy (automatic TLS via Let's Encrypt).
      traefik.service = {
        image = "traefik:v3.6";
        container_name = "netbird-traefik";
        restart = "unless-stopped";
        networks.netbird.ipv4_address = "172.30.0.10";
        command = [
          "--log.level=INFO"
          "--accesslog=true"
          "--providers.docker=true"
          "--providers.docker.exposedbydefault=false"
          "--providers.docker.network=netbird"
          "--entrypoints.web.address=:80"
          "--entrypoints.websecure.address=:443"
          "--entrypoints.websecure.allowACMEByPass=true"
          # Disable timeouts for long-lived gRPC streams.
          "--entrypoints.websecure.transport.respondingTimeouts.readTimeout=0"
          "--entrypoints.websecure.transport.respondingTimeouts.writeTimeout=0"
          "--entrypoints.websecure.transport.respondingTimeouts.idleTimeout=0"
          "--entrypoints.web.http.redirections.entrypoint.to=websecure"
          "--entrypoints.web.http.redirections.entrypoint.scheme=https"
          "--certificatesresolvers.letsencrypt.acme.email=yohan.zbinden@gmail.com"
          "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
          "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
          "--serverstransport.forwardingtimeouts.responseheadertimeout=0s"
          "--serverstransport.forwardingtimeouts.idleconntimeout=0s"
          "--providers.file.filename=/etc/traefik/dynamic.yaml"
        ];
        ports = [
          "443:443"
          "80:80"
        ];
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
          "${stateDir}/traefik:/letsencrypt"
          "${traefikDynamic}:/etc/traefik/dynamic.yaml:ro"
        ];
      };

      # UI dashboard.
      dashboard.service = {
        image = "netbirdio/dashboard:v2.90.5";
        container_name = "netbird-dashboard";
        restart = "unless-stopped";
        networks = [ "netbird" ];
        env_file = [ "${dashboardEnv}" ];
        labels = {
          "traefik.enable" = "true";
          "traefik.http.routers.netbird-dashboard.rule" = "Host(`${domain}`)";
          "traefik.http.routers.netbird-dashboard.entrypoints" = "websecure";
          "traefik.http.routers.netbird-dashboard.tls" = "true";
          "traefik.http.routers.netbird-dashboard.tls.certresolver" = "letsencrypt";
          "traefik.http.routers.netbird-dashboard.service" = "dashboard";
          "traefik.http.routers.netbird-dashboard.priority" = "1";
          "traefik.http.services.dashboard.loadbalancer.server.port" = "80";
        };
      };

      # Combined server (Management + Signal + Relay + STUN + embedded Dex).
      netbird-server.service = {
        image = "netbirdio/netbird-server:0.74.7";
        container_name = "netbird-server";
        restart = "unless-stopped";
        networks = [ "netbird" ];
        ports = [ "3478:3478/udp" ];
        volumes = [
          "${stateDir}/data:/var/lib/netbird"
          "${config.sops.templates."netbird-config.yaml".path}:/etc/netbird/config.yaml:ro"
        ];
        command = [
          "--config"
          "/etc/netbird/config.yaml"
        ];
        labels = {
          "traefik.enable" = "true";
          # gRPC router (needs an h2c backend for HTTP/2 cleartext).
          "traefik.http.routers.netbird-grpc.rule" =
            "Host(`${domain}`) && (PathPrefix(`/signalexchange.SignalExchange/`) || PathPrefix(`/management.ManagementService/`) || PathPrefix(`/management.ProxyService/`))";
          "traefik.http.routers.netbird-grpc.entrypoints" = "websecure";
          "traefik.http.routers.netbird-grpc.tls" = "true";
          "traefik.http.routers.netbird-grpc.tls.certresolver" = "letsencrypt";
          "traefik.http.routers.netbird-grpc.service" = "netbird-server-h2c";
          "traefik.http.routers.netbird-grpc.priority" = "100";
          # Backend router (relay, WebSocket, API, OAuth2).
          "traefik.http.routers.netbird-backend.rule" =
            "Host(`${domain}`) && (PathPrefix(`/relay`) || PathPrefix(`/ws-proxy/`) || PathPrefix(`/api`) || PathPrefix(`/oauth2`))";
          "traefik.http.routers.netbird-backend.entrypoints" = "websecure";
          "traefik.http.routers.netbird-backend.tls" = "true";
          "traefik.http.routers.netbird-backend.tls.certresolver" = "letsencrypt";
          "traefik.http.routers.netbird-backend.service" = "netbird-server";
          "traefik.http.routers.netbird-backend.priority" = "100";
          "traefik.http.services.netbird-server.loadbalancer.server.port" = "80";
          "traefik.http.services.netbird-server-h2c.loadbalancer.server.port" = "80";
          "traefik.http.services.netbird-server-h2c.loadbalancer.server.scheme" = "h2c";
        };
      };

      # NetBird proxy - exposes internal resources, gated by CrowdSec.
      # NB_PROXY_TOKEN and the CrowdSec bouncer key are provisioned post-deploy
      # (see ../netbird.nix header) and delivered via the sops-rendered proxy.env.
      proxy.service = {
        image = "netbirdio/reverse-proxy:0.74.7";
        container_name = "netbird-proxy";
        restart = "unless-stopped";
        networks = [ "netbird" ];
        ports = [ "51820:51820/udp" ];
        depends_on = {
          netbird-server.condition = "service_started";
          crowdsec.condition = "service_healthy";
        };
        env_file = [ "${config.sops.templates."netbird-proxy.env".path}" ];
        volumes = [ "${stateDir}/proxy-certs:/certs" ];
        labels = {
          # TCP passthrough for any unmatched domain (proxy terminates its own TLS).
          "traefik.enable" = "true";
          "traefik.tcp.routers.proxy-passthrough.entrypoints" = "websecure";
          "traefik.tcp.routers.proxy-passthrough.rule" = "HostSNI(`*`)";
          "traefik.tcp.routers.proxy-passthrough.tls.passthrough" = "true";
          "traefik.tcp.routers.proxy-passthrough.service" = "proxy-tls";
          "traefik.tcp.routers.proxy-passthrough.priority" = "1";
          "traefik.tcp.services.proxy-tls.loadbalancer.server.port" = "8443";
          "traefik.tcp.services.proxy-tls.loadbalancer.serverstransport" = "pp-v2@file";
        };
      };

      # CrowdSec LAPI. The linux collection reinstalls on start via COLLECTIONS;
      # decisions and the registered proxy bouncer persist in the crowdsec-db volume.
      crowdsec.service = {
        image = "crowdsecurity/crowdsec:v1.7.7";
        container_name = "netbird-crowdsec";
        restart = "unless-stopped";
        networks = [ "netbird" ];
        environment.COLLECTIONS = "crowdsecurity/linux";
        volumes = [ "${stateDir}/crowdsec-db:/var/lib/crowdsec/data" ];
        healthcheck = {
          test = [
            "CMD"
            "cscli"
            "lapi"
            "status"
          ];
          interval = "10s";
          timeout = "5s";
          retries = 15;
        };
        labels = {
          "traefik.enable" = "false";
        };
      };
    };
  };
}
