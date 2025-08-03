_: {
  sops.defaultSopsFile = ./ocr-secrets.yml;
  sops.secrets = {
    netdata-claim-token = {
      path = "/var/lib/netdata/cloud.d/token";
    };
    k3s-server-token = {};
    cloudflared-token = {};
    "homepage/cachix-api-key" = {};
    "homepage/argocd-api-key" = {};
    "homepage/cloudflare-account-id" = {};
    "homepage/cloudflare-api-key" = {};
    "homepage/jellyfin-api-key" = {};
    "homepage/jellyseerr-api-key" = {};
    "homepage/radarr-api-key" = {};
    "homepage/sonarr-api-key" = {};
    "homepage/qbittorrent-username" = {};
    "homepage/qbittorrent-password" = {};
    "vikunja/user" = {};
    "vikunja/password" = {};
    "kDrive/api-key" = {};
  };
}
