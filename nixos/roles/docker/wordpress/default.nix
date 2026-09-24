# WordPress with its own MariaDB, fronted by Traefik which terminates TLS and
# gets the certificate from Let's Encrypt (HTTP-01 challenge on port 80).
#
# yoyozbi.wordpress.domain and yoyozbi.wordpress.acmeEmail must be set, and the
# domain (plus www.<domain>) must resolve to this host with 80/443 reachable.
# The database password never leaves the host, so it is generated on first
# start; WordPress generates its own salts into wp-config.php on first start.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.yoyozbi.wordpress;

  # The official mariadb image runs as 999; apache in the wordpress image
  # serves (and reads the db password file on every request) as www-data (33).
  mariadbUid = 999;
  wwwDataUid = 33;

  dbPasswordFile = "${cfg.dataDir}/db-password";

  phpIni = pkgs.writeText "wordpress-uploads.ini" ''
    upload_max_filesize = 64M
    post_max_size = 64M
    memory_limit = 256M
  '';

  # Routers live in a file provider rather than docker labels so traefik
  # doesn't need the docker socket.
  dynamicConfig = (pkgs.formats.yaml { }).generate "traefik-dynamic.yml" {
    http = {
      routers = {
        wordpress = {
          rule = "Host(`${cfg.domain}`)";
          entryPoints = [ "websecure" ];
          service = "wordpress";
          tls.certResolver = "letsencrypt";
        };
        # Separate router, so a missing www record only fails this certificate
        # instead of the apex one.
        wordpress-www = {
          rule = "Host(`www.${cfg.domain}`)";
          entryPoints = [ "websecure" ];
          service = "wordpress";
          middlewares = [ "www-to-apex" ];
          tls.certResolver = "letsencrypt";
        };
      };
      middlewares.www-to-apex.redirectRegex = {
        regex = "^https://www\\.(.*)";
        replacement = "https://$1";
        permanent = true;
      };
      services.wordpress.loadBalancer.servers = [ { url = "http://wordpress:80"; } ];
    };
  };
in
{
  imports = [
    inputs.arion.nixosModules.arion
  ];

  options.yoyozbi.wordpress = with lib; {
    domain = mkOption {
      type = types.str;
      example = "example.com";
      description = "Apex domain served by WordPress; www.<domain> redirects to it.";
    };

    acmeEmail = mkOption {
      type = types.str;
      description = "Contact email for the Let's Encrypt account.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/wordpress";
      description = "Holds the WordPress install, the MariaDB datadir and the ACME certificates.";
    };
  };

  config = {
    virtualisation.arion.backend = "docker";

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root -"
      "d ${cfg.dataDir}/html 0755 ${toString wwwDataUid} ${toString wwwDataUid} -"
      "d ${cfg.dataDir}/mariadb 0700 ${toString mariadbUid} ${toString mariadbUid} -"
      "d ${cfg.dataDir}/letsencrypt 0700 root root -"
    ];

    systemd.services.arion-wordpress = {
      unitConfig.RequiresMountsFor = [ cfg.dataDir ];

      # MariaDB only reads its password when initialising the datadir, so it
      # has to stay stable: generate it once and keep it next to the data.
      # mariadb reads it after dropping to 999, wordpress as www-data (33).
      preStart = ''
        if [ ! -s ${dbPasswordFile} ]; then
          (umask 077 && head -c 36 /dev/urandom | base64 -w 0 | tr '+/' '-_' > ${dbPasswordFile})
        fi
        chown ${toString mariadbUid}:${toString wwwDataUid} ${dbPasswordFile}
        chmod 0440 ${dbPasswordFile}
      '';
    };

    virtualisation.arion.projects.wordpress.settings = {
      services = {
        traefik.service = {
          image = "docker.io/library/traefik:v3.7.13";
          container_name = "wordpress-traefik";
          restart = "unless-stopped";
          command = [
            "--providers.file.filename=/etc/traefik/dynamic.yml"
            "--entryPoints.web.address=:80"
            "--entryPoints.web.http.redirections.entryPoint.to=websecure"
            "--entryPoints.web.http.redirections.entryPoint.scheme=https"
            "--entryPoints.websecure.address=:443"
            "--certificatesResolvers.letsencrypt.acme.email=${cfg.acmeEmail}"
            "--certificatesResolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
            "--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=web"
            "--ping=true"
            "--global.checkNewVersion=false"
            "--global.sendAnonymousUsage=false"
          ];
          ports = [
            "80:80"
            "443:443"
          ];
          volumes = [
            "${dynamicConfig}:/etc/traefik/dynamic.yml:ro"
            "${cfg.dataDir}/letsencrypt:/letsencrypt:rw"
          ];
          depends_on = [ "wordpress" ];
          healthcheck = {
            test = [
              "CMD"
              "traefik"
              "healthcheck"
              "--ping"
            ];
            interval = "30s";
            timeout = "5s";
            retries = 5;
            start_period = "30s";
          };
        };

        wordpress.service = {
          image = "docker.io/library/wordpress:7.1.2-apache";
          container_name = "wordpress";
          restart = "unless-stopped";
          depends_on = {
            db = {
              condition = "service_healthy";
            };
          };
          volumes = [
            "${cfg.dataDir}/html:/var/www/html:rw"
            "${phpIni}:/usr/local/etc/php/conf.d/uploads.ini:ro"
            "${dbPasswordFile}:/run/secrets/db-password:ro"
          ];
          # The image's wp-config.php already trusts X-Forwarded-Proto from
          # traefik, so WordPress knows it's served over https.
          environment = {
            WORDPRESS_DB_HOST = "db";
            WORDPRESS_DB_NAME = "wordpress";
            WORDPRESS_DB_USER = "wordpress";
            WORDPRESS_DB_PASSWORD_FILE = "/run/secrets/db-password";
          };
        };

        db.service = {
          image = "docker.io/library/mariadb:11.8.9";
          container_name = "wordpress-mariadb";
          restart = "unless-stopped";
          # tiny2 only has 1 GB of RAM; the default 128M pool is more than a
          # single small site needs.
          command = [ "--innodb-buffer-pool-size=64M" ];
          volumes = [
            "${cfg.dataDir}/mariadb:/var/lib/mysql:rw"
            "${dbPasswordFile}:/run/secrets/db-password:ro"
          ];
          environment = {
            MARIADB_DATABASE = "wordpress";
            MARIADB_USER = "wordpress";
            MARIADB_PASSWORD_FILE = "/run/secrets/db-password";
            MARIADB_RANDOM_ROOT_PASSWORD = "1";
          };
          healthcheck = {
            test = [
              "CMD"
              "healthcheck.sh"
              "--connect"
              "--innodb_initialized"
            ];
            interval = "10s";
            timeout = "5s";
            retries = 5;
            start_period = "30s";
          };
        };
      };
    };
  };
}
