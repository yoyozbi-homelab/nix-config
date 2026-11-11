# tiny2 watches the rest of the homelab with Uptime Kuma (role docker/uptime-kuma).
#
# rp and the ocr1 cluster's services are reached through the Pangolin machine
# client (role docker/pangolin-client). It needs these private resources in
# Pangolin, all granted to tiny2's machine client:
#   - rp site:   192.168.1.2, TCP 8000                           (paperless)
#   - ocr1 site: main-cluster-rw.cnpg-system.svc.cluster.local, TCP 5432,
#                alias postgres.ocr1.internal                    (CNPG)
# ocr1 itself (10.0.0.93: ingress, k3s API) sits on tiny2's own VCN subnet, so
# those checks go there directly.
#
# A Cloudflare Access or Pangolin SSO login redirect is served without touching
# the app, so the public check of a gated service only proves the gate is up.
# Those services get a second check that goes to the origin through the tunnel.
#
# Where a service has a health endpoint that checks its backends (database,
# cache, worker), the check uses it: a login page or SPA shell answers 2xx even
# with the database down.
#
# Backups report to push monitors (group "Backups"): each run calls
# https://status.yohanzbinden.ch/api/push/<token>?status=up|down, and a run
# that never happens shows up as a missed push.
{ config, lib, ... }:
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

  # Kuma sends a browser Accept header by default, and some APIs (Django REST
  # Framework, Longhorn's) then answer with an HTML page instead of JSON.
  # `query` is JSONata; its result is compared as a string to `expected`.
  jsonQuery =
    parent: name: url: headers: query: expected: extra:
    http parent name url (
      {
        type = "json-query";
        headers = builtins.toJSON ({ Accept = "application/json"; } // headers);
        json_path = query;
        json_path_operator = "==";
        expected_value = expected;
      }
      // extra
    );

  # Through the ocr1 site to the cluster's ingress, picked by Host header. Not
  # following redirects: a relative Location would leave the Host header behind.
  ingressExtra = {
    max_redirects = 0;
    accepted_statuscodes = [ "200-399" ];
  };
  ingress =
    name: host: path:
    http "ocr1" name "http://${ocr1}${path}" (
      ingressExtra // { headers = builtins.toJSON { Host = host; }; }
    );
  ingressKeyword =
    name: host: path: keyword:
    ingress name host path // { type = "keyword"; inherit keyword; };
  ingressJson =
    name: host: path: query: expected:
    jsonQuery "ocr1" name "http://${ocr1}${path}" { Host = host; } query expected {
      max_redirects = 0;
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

  # Backups run daily: 25h leaves an hour of slack for a late or slow run.
  # No retries, so a missed or failed run alerts right away. The token is a
  # secret because anyone holding it can mark the backup as done.
  pushMonitors = {
    backup-rp = {
      name = "rp (paperless, duplicity)";
      tokenSecret = "kuma-push-token-rp-backup";
    };
    backup-cnpg = {
      name = "ocr1 Postgres dump";
      tokenSecret = "kuma-push-token-cnpg-backup";
    };
    backup-supersync = {
      name = "ocr1 Supersync data";
      tokenSecret = "kuma-push-token-supersync-backup";
    };
  };

  # Rendered at activation, mounted by the uptime-kuma role like any entity.
  secretTemplates = {
    # Logs in as a role with no rights beyond LOGIN (declared in the flux
    # repo's CNPG cluster), so this password guards nothing else. Characters
    # that are special in a URL must be percent-encoded in the secret.
    postgres =
      defaults
      // {
        type = "postgres";
        parent_name = "ocr1";
        name = "Postgres (main-cluster)";
        database_connection_string = "postgres://uptime_kuma:${config.sops.placeholder.uptime-kuma-postgres-password}@postgres.ocr1.internal:5432/postgres";
        query = "SELECT 1";
      };

    # The plain Paperless check only sees the login redirect, which is served
    # without touching Postgres or Valkey. /api/status/ reports both, plus the
    # Celery worker. The token belongs to a Paperless user whose only
    # permission is "view system monitoring", so it can't read documents.
    rp-paperless-status =
      jsonQuery "rp" "Paperless (Postgres, Valkey, Celery)" "http://${rp}:8000/api/status/"
        {
          Host = "paperless.yohanzbinden.ch";
          Authorization = "Token ${config.sops.placeholder.paperless-status-token}";
        }
        # Joined rather than a boolean, so the failure message shows which
        # part is down (e.g. "OK,ERROR,OK").
        ''$join([database.status, tasks.redis_status, tasks.celery_status], ",")''
        "OK,OK,OK"
        { max_redirects = 0; };

    # /readyz includes the datastore, but anonymous requests get 401. The
    # token is a ServiceAccount's bound only to system:public-info-viewer
    # (flux repo, apps/uptime-kuma), which can read /readyz, /livez, /healthz
    # and /version and nothing else.
    ocr1-k3s-api = http "ocr1" "k3s API" "https://${ocr1}:6443/readyz" {
      ignore_tls = true;
      headers = builtins.toJSON {
        Authorization = "Bearer ${config.sops.placeholder.k3s-readyz-token}";
      };
    };
  }
  // lib.mapAttrs (_: m: {
    type = "push";
    parent_name = "backups";
    inherit (m) name;
    push_token = config.sops.placeholder.${m.tokenSecret};
    interval = 90000;
    max_retries = 0;
    notification_name_list = [ "ntfy" ];
  }) pushMonitors;
in
{
  sops.secrets = {
    uptime-kuma-postgres-password = { };
    paperless-status-token = { };
    k3s-readyz-token = { };
    ntfy-server-url = { };
    ntfy-topic = { };
  }
  // lib.mapAttrs' (_: m: lib.nameValuePair m.tokenSecret { }) pushMonitors;

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
  }
  // lib.mapAttrs' (
    id: entity:
    lib.nameValuePair "autokuma-${id}.json" {
      content = builtins.toJSON entity;
      restartUnits = [ "arion-uptime-kuma.service" ];
    }
  ) secretTemplates;

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
      }
      // lib.mapAttrs (id: _: config.sops.templates."autokuma-${id}.json".path) secretTemplates;

      entities = {
        public = group "Public";
        gates = group "Auth gates";
        ocr1 = group "ocr1 (internal)";
        rp = group "rp (internal)";
        seedbox = group "Seedbox";
        backups = group "Backups";

        # /api/v1/ is Pangolin's API root; the dashboard is a static shell.
        pangolin = public "Pangolin" "https://pangolin.yohanzbinden.ch/api/v1/";
        # /alive takes a database connection, so it fails with the database.
        vaultwarden = public "Vaultwarden" "https://vault.yohanzbinden.ch/alive";
        # /health pings the database (and Redis, if enabled); 500 otherwise.
        vikunja = public "Vikunja" "https://tasks.yohanzbinden.ch/health";
        supersync = jsonQuery "public" "Supersync" "https://supersync.yohanzbinden.ch/health" { } "db" "connected" { };
        # No unauthenticated endpoint touches its database; that is covered by
        # the Postgres monitor.
        jellyseerr = public "Jellyseerr" "https://jellyseerr.yohanzbinden.ch/";
        # WordPress' home page already fails without its database.
        teamsolid = public "teamsolid.ch" "https://teamsolid.ch/";

        gate-flux = gate "Flux" "https://flux.yohanzbinden.ch/";
        gate-longhorn = gate "Longhorn" "https://longhorn.yohanzbinden.ch/";
        gate-bookmarks = gate "Bookmarks" "https://bookmarks.yohanzbinden.ch/";
        gate-homepage = gate "Homepage" "https://homepage.yohanzbinden.ch/";
        gate-traefik-ocr1 = gate "Traefik (ocr1)" "https://traefik-ocr1.yohanzbinden.ch/";
        gate-paperless = gate "Paperless" "https://paperless.yohanzbinden.ch/";

        # Down when any Flux resource (Kustomization, HelmRelease, ...) fails
        # to reconcile, not only when the UI is down.
        ocr1-flux =
          ingressJson "Flux reconcilers" "flux.yohanzbinden.ch" "/api/v1/report"
            "$sum(spec.reconcilers.stats.failing) = 0 and spec.sync.ready"
            "true";
        # Counts volumes that are degraded or faulted.
        ocr1-longhorn =
          ingressJson "Longhorn volumes" "longhorn.yohanzbinden.ch" "/v1/volumes"
            ''$count(data[robustness != "healthy"])''
            "0";
        ocr1-bookmarks = ingress "Bookmarks" "bookmarks.yohanzbinden.ch" "/";
        ocr1-homepage = ingressKeyword "Homepage" "homepage.yohanzbinden.ch" "/api/healthcheck" "up";
        # The dashboard ingress only routes /dashboard/ and /api/.
        ocr1-traefik = ingress "Traefik dashboard" "traefik-ocr1.yohanzbinden.ch" "/dashboard/";

        # Paperless only accepts its public hostname (PAPERLESS_URL).
        rp-paperless = http "rp" "Paperless" "http://${rp}:8000/" {
          headers = builtins.toJSON { Host = "paperless.yohanzbinden.ch"; };
          max_redirects = 0;
          accepted_statuscodes = [ "200-399" ];
        };

        seedbox-jellyfin = seedbox "Jellyfin" "https://yohan-jellyfin.cloud.seedboxes.cc/health";
        seedbox-radarr = seedbox "Radarr" "https://yohan-radarr.cloud.seedboxes.cc/ping";
        seedbox-sonarr = seedbox "Sonarr" "https://yohan-sonarr.cloud.seedboxes.cc/ping";
        # Every qBittorrent API call needs a login.
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
