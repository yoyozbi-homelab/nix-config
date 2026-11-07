# tiny2 watches the rest of the homelab with Uptime Kuma (role docker/uptime-kuma).
#
# Internal checks go through the Pangolin machine client (role
# docker/pangolin-client). They need these private resources in Pangolin,
# all granted to tiny2's machine client:
#   - rp site:   192.168.1.2, TCP 8000                           (paperless)
#   - ocr1 site: 10.0.0.93, TCP 80 and 6443                      (ingress, k3s API)
#   - ocr1 site: main-cluster-rw.cnpg-system.svc.cluster.local, TCP 5432,
#                alias postgres.ocr1.internal                    (CNPG)
#
# A Cloudflare Access or Pangolin SSO login redirect is served without touching
# the app, so the public check of a gated service only proves the gate is up.
# Those services get a second check that goes to the origin through the tunnel.
{ config, ... }:
let
  ocr1 = config.networking.yoyozbi.hosts.ocr1.internalIp;
  rp = config.networking.yoyozbi.hosts.rp.internalIp;

  # tiny1 (Pangolin) runs at 70%+ CPU steal, so a single slow answer is not an
  # outage: only alert after a few failed checks.
  defaults = {
    interval = 60;
    retry_interval = 60;
    max_retries = 3;
    notification_name_list = [ "ntfy" ];
  };

  group = name: {
    type = "group";
    inherit name;
  };

  http =
    parent: name: url: extra:
    defaults
    // {
      type = "http";
      parent_name = parent;
      inherit name url;
      accepted_statuscodes = [ "200-299" ];
    }
    // extra;

  # Through the ocr1 site to the cluster's ingress, picked by Host header. Not
  # following redirects: a relative Location would leave the Host header behind.
  ingress =
    name: host: path:
    http "ocr1" name "http://${ocr1}${path}" {
      headers = builtins.toJSON { Host = host; };
      max_redirects = 0;
      accepted_statuscodes = [ "200-399" ];
    };

  # Expect the login redirect itself (not following it).
  gate =
    name: url:
    http "gates" name url {
      max_redirects = 0;
      accepted_statuscodes = [ "300-399" ];
    };

  public = name: url: http "public" name url { };
  seedbox = name: url: http "seedbox" name url { accepted_statuscodes = [ "200-399" ]; };
in
{
  sops.secrets = {
    uptime-kuma-postgres-password = { };
    ntfy-server-url = { };
    ntfy-topic = { };
  };

  sops.templates = {
    "autokuma-ntfy.json" = {
      content = builtins.toJSON {
        type = "notification";
        name = "ntfy";
        active = true;
        isDefault = true;
        config = {
          type = "ntfy";
          name = "ntfy";
          ntfyserverurl = config.sops.placeholder.ntfy-server-url;
          ntfytopic = config.sops.placeholder.ntfy-topic;
          ntfyPriority = 5;
          ntfyAuthenticationMethod = "none";
        };
      };
      restartUnits = [ "arion-uptime-kuma.service" ];
    };

    # Logs in as a role with no rights beyond LOGIN (declared in the flux
    # repo's CNPG cluster), so this password guards nothing else. Hex, so it
    # needs no escaping in the URL.
    "autokuma-postgres.json" = {
      content = builtins.toJSON (
        defaults
        // {
          type = "postgres";
          parent_name = "ocr1";
          name = "Postgres (main-cluster)";
          database_connection_string = "postgres://uptime_kuma:${config.sops.placeholder.uptime-kuma-postgres-password}@postgres.ocr1.internal:5432/postgres";
          query = "SELECT 1";
        }
      );
      restartUnits = [ "arion-uptime-kuma.service" ];
    };
  };

  yoyozbi = {
    cloudflared.hostNetwork = true;

    uptimeKuma = {
      # The Pangolin client's DNS proxy answers aliases (postgres.ocr1.internal).
      # If the tunnel is down it stops answering and lookups fall through to
      # 1.1.1.1, so public checks keep working.
      dns = [
        config.yoyozbi.pangolinClient.dnsProxy
        "1.1.1.1"
      ];

      secretEntities = {
        ntfy = config.sops.templates."autokuma-ntfy.json".path;
        postgres = config.sops.templates."autokuma-postgres.json".path;
      };

      entities = {
        public = group "Public";
        gates = group "Auth gates";
        ocr1 = group "ocr1 (internal)";
        rp = group "rp (internal)";
        seedbox = group "Seedbox";

        pangolin = public "Pangolin" "https://pangolin.yohanzbinden.ch/";
        vaultwarden = public "Vaultwarden" "https://vault.yohanzbinden.ch/";
        vikunja = public "Vikunja" "https://tasks.yohanzbinden.ch/";
        supersync = public "Supersync" "https://supersync.yohanzbinden.ch/";
        jellyseerr = public "Jellyseerr" "https://jellyseerr.yohanzbinden.ch/";
        teamsolid = public "teamsolid.ch" "https://teamsolid.ch/";

        gate-flux = gate "Flux" "https://flux.yohanzbinden.ch/";
        gate-longhorn = gate "Longhorn" "https://longhorn.yohanzbinden.ch/";
        gate-bookmarks = gate "Bookmarks" "https://bookmarks.yohanzbinden.ch/";
        gate-homepage = gate "Homepage" "https://homepage.yohanzbinden.ch/";
        gate-traefik-ocr1 = gate "Traefik (ocr1)" "https://traefik-ocr1.yohanzbinden.ch/";
        gate-paperless = gate "Paperless" "https://paperless.yohanzbinden.ch/";

        ocr1-flux = ingress "Flux" "flux.yohanzbinden.ch" "/";
        ocr1-longhorn = ingress "Longhorn" "longhorn.yohanzbinden.ch" "/";
        ocr1-bookmarks = ingress "Bookmarks" "bookmarks.yohanzbinden.ch" "/";
        ocr1-homepage = ingress "Homepage" "homepage.yohanzbinden.ch" "/";
        # The dashboard ingress only routes /dashboard/ and /api/.
        ocr1-traefik = ingress "Traefik dashboard" "traefik-ocr1.yohanzbinden.ch" "/dashboard/";
        # Anonymous requests get 401: that still proves the API server answers.
        ocr1-k3s-api = http "ocr1" "k3s API" "https://${ocr1}:6443/livez" {
          ignore_tls = true;
          accepted_statuscodes = [
            "200-299"
            "401"
          ];
        };

        # Paperless only accepts its public hostname (PAPERLESS_URL).
        rp-paperless = http "rp" "Paperless" "http://${rp}:8000/" {
          headers = builtins.toJSON { Host = "paperless.yohanzbinden.ch"; };
          max_redirects = 0;
          accepted_statuscodes = [ "200-399" ];
        };

        seedbox-jellyfin = seedbox "Jellyfin" "https://yohan-jellyfin.cloud.seedboxes.cc/";
        seedbox-radarr = seedbox "Radarr" "https://yohan-radarr.cloud.seedboxes.cc/";
        seedbox-sonarr = seedbox "Sonarr" "https://yohan-sonarr.cloud.seedboxes.cc/";
        seedbox-qbittorrent = seedbox "qBittorrent" "https://yohan-qbittorrent.cloud.seedboxes.cc/";
      };
    };
  };

  # Every tunnel check would fail at once without the client; say so in the
  # unit graph rather than leaving it implicit.
  systemd.services.arion-uptime-kuma = {
    wants = [ "arion-pangolin-client.service" ];
    after = [ "arion-pangolin-client.service" ];
  };
}
