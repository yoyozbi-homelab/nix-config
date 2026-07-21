# NetBird self-hosted control plane, deployed as an arion (docker-compose) stack.
#
# Topology (see ./netbird/arion.nix):
#   traefik            -> TLS/ACME + routing (80/443)
#   netbird-server     -> combined Management + Signal + Relay + STUN + Dex (3478/udp)
#   dashboard          -> web UI
#   proxy              -> exposes internal resources (51820/udp), gated by CrowdSec
#   crowdsec           -> LAPI / IP reputation
#
# External prerequisites (owned outside this repo):
#   DNS: A  netbird -> 144.24.255.32 ; CNAME *.netbird -> netbird.yohanzbinden.ch
#   OCI security list ingress: TCP 80, TCP 443, UDP 3478, UDP 51820
#
# Two secrets are minted by the running stack (as in upstream getting-started.sh),
# so after the FIRST deploy, populate them in netbird-secrets.yml and rebuild:
#   1. proxy token:
#        docker compose -p netbird exec -T netbird-server \
#          /go/bin/netbird-server token create --name default-proxy \
#          --config /etc/netbird/config.yaml | awk '/^Token:/{print $2}'
#      -> netbird-proxy-token
#   2. CrowdSec bouncer (register the pre-generated key so it matches proxy.env):
#        docker exec netbird-crowdsec cscli bouncers add netbird-proxy \
#          -k "$(sops -d --extract '["netbird-crowdsec-bouncer-key"]' \
#                nixos/roles/docker/netbird-secrets.yml)"
#   Until then the proxy container crash-loops; the rest of the stack is healthy.
{ config, inputs, ... }:
let
  stateDir = "/var/lib/netbird";
  secretsFile = ./netbird-secrets.yml;
in
{
  imports = [
    inputs.arion.nixosModules.arion
    ./netbird/arion.nix
  ];

  virtualisation.arion.backend = "docker";

  # The OCI security list is the real ingress gate (docker-published ports
  # bypass the host firewall via DOCKER-USER); declared here for clarity and to
  # match the documented port set.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [
    3478 # STUN (netbird-server)
    51820 # WireGuard for the netbird reverse-proxy P2P connections
  ];

  # Declarative, backup-friendly persistence for the arion bind mounts.
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 root root -"
    "d ${stateDir}/data 0750 root root -"
    "d ${stateDir}/traefik 0750 root root -"
    "d ${stateDir}/proxy-certs 0750 root root -"
    "d ${stateDir}/crowdsec-db 0750 root root -"
  ];

  # Raw secrets live encrypted in netbird-secrets.yml (inherits the .sops.yaml
  # `secrets.yml$` key group: tiny1 + laptop admin). The config/env files that
  # embed them are rendered at activation via sops.templates, so the plaintext
  # secrets never enter the nix store.
  sops.secrets = {
    netbird-auth-secret.sopsFile = secretsFile;
    netbird-encryption-key.sopsFile = secretsFile;
    netbird-proxy-token.sopsFile = secretsFile;
    netbird-crowdsec-bouncer-key.sopsFile = secretsFile;
  };

  sops.templates."netbird-config.yaml".content = ''
    # Combined NetBird Server Configuration
    server:
      listenAddress: ":80"
      exposedAddress: "https://netbird.yohanzbinden.ch:443"
      stunPorts:
        - 3478
      metricsPort: 9090
      healthcheckAddress: ":9000"
      logLevel: "info"
      logFile: "console"

      authSecret: "${config.sops.placeholder.netbird-auth-secret}"
      dataDir: "/var/lib/netbird"

      auth:
        issuer: "https://netbird.yohanzbinden.ch/oauth2"
        signKeyRefreshEnabled: true
        dashboardRedirectURIs:
          - "https://netbird.yohanzbinden.ch/nb-auth"
          - "https://netbird.yohanzbinden.ch/nb-silent-auth"
        cliRedirectURIs:
          - "http://localhost:53000/"

      reverseProxy:
        trustedHTTPProxies:
          - "172.30.0.10/32"

      store:
        engine: "sqlite"
        encryptionKey: "${config.sops.placeholder.netbird-encryption-key}"
  '';

  sops.templates."netbird-proxy.env".content = ''
    # NetBird Proxy Configuration
    NB_PROXY_DEBUG_LOGS=false
    # Reach management over the internal docker network (avoids hairpin NAT).
    NB_PROXY_MANAGEMENT_ADDRESS=http://netbird-server:80
    NB_PROXY_ALLOW_INSECURE=true
    # Public URL where this proxy is reachable (cluster registration).
    NB_PROXY_DOMAIN=netbird.yohanzbinden.ch
    NB_PROXY_ADDRESS=:8443
    NB_PROXY_TOKEN=${config.sops.placeholder.netbird-proxy-token}
    NB_PROXY_CERTIFICATE_DIRECTORY=/certs
    NB_PROXY_ACME_CERTIFICATES=true
    NB_PROXY_ACME_CHALLENGE_TYPE=tls-alpn-01
    NB_PROXY_FORWARDED_PROTO=https
    # PROXY protocol preserves client IPs through Traefik's TCP passthrough.
    NB_PROXY_PROXY_PROTOCOL=true
    # Trust Traefik's static ingress IP for PROXY protocol headers.
    NB_PROXY_TRUSTED_PROXIES=172.30.0.10
    NB_PROXY_CROWDSEC_API_URL=http://crowdsec:8080
    NB_PROXY_CROWDSEC_API_KEY=${config.sops.placeholder.netbird-crowdsec-bouncer-key}
  '';
}
