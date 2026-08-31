{ inputs, config, ... }:
let
  stateDir = "/var/lib/monitoring";
  grafanaUid = 472;
  prometheusUid = 65534; # nobody
in
{
  imports = [
    inputs.arion.nixosModules.arion
  ];

  assertions = [
    {
      assertion = config.sops.secrets ? grafana-admin-password;
      message = ''
        The stats roles requires a SOPS secret named `grafana-admin-password`.
      '';
    }
  ];

  # Grafana runs as uid 472 inside the container and must be able to read this.
  sops.secrets.grafana-admin-password.mode = "0444";

  virtualisation.arion.backend = "docker";

  networking.firewall.allowedTCPPorts = [
    3000 # Grafana
    9090 # Prometheus
  ];

  # Both images drop privileges, so the bind-mounted state dirs must be owned by
  # the container uid: grafana runs as 472, prometheus as nobody (65534).
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 root root -"
    "d ${stateDir}/grafana 0750 ${toString grafanaUid} ${toString grafanaUid} -"
    "d ${stateDir}/prometheus 0750 ${toString prometheusUid} ${toString prometheusUid} -"
  ];

  virtualisation.arion.projects.monitoring.settings = {
    services = {
      grafana.service = {
        image = "docker.io/grafana/grafana:13.2.0";
        container_name = "grafana";
        restart = "unless-stopped";
        volumes = [
          "${stateDir}/grafana:/var/lib/grafana:rw"
          "${./config/grafana-datasource.yaml}:/etc/grafana/provisioning/datasources/datasource.yaml:ro"
          "${./config/dashboards}:/etc/grafana/provisioning/dashboards:ro"
          "${config.sops.secrets."grafana-admin-password".path}:/run/secrets/grafana-admin-password:ro"
        ];
        environment = {
          "GF_USERS_ALLOW_SIGN_UP" = "false";
          "GF_SECURITY_ADMIN_PASSWORD_FILE" = "/run/secrets/grafana-admin-password";
        };
        depends_on = [ "prometheus" ];
        ports = [
          "3000:3000"
        ];
      };

      prometheus.service = {
        image = "docker.io/prom/prometheus:v3.14.0";
        container_name = "prometheus";
        restart = "unless-stopped";
        volumes = [
          "${stateDir}/prometheus:/prometheus:rw"
          "${./config/prometheus-config.yaml}:/etc/prometheus/prometheus.yml:ro"
        ];
        command = [
          "--config.file=/etc/prometheus/prometheus.yml"
          "--storage.tsdb.path=/prometheus"
        ];

        depends_on = [
          "cadvisor"
          "node-exporter"
        ];
        ports = [
          "9090:9090"
        ];
      };

      cadvisor.service = {
        image = "ghcr.io/google/cadvisor:v0.60.5";
        container_name = "cadvisor";
        restart = "unless-stopped";
        privileged = true;
        volumes = [
          "/:/rootfs:ro"
          "/var/run:/var/run:ro"
          "/sys:/sys:ro"
          "/var/lib/docker/:/var/lib/docker:ro"
          "/dev/disk/:/dev/disk:ro"
        ];
        devices = [
          "/dev/kmsg:/dev/kmsg"
        ];
        ports = [
          "8080:8080"
        ];
      };

      node-exporter.service = {
        image = "quay.io/prometheus/node-exporter:v1.12.1";
        container_name = "node-exporter";
        restart = "unless-stopped";
        volumes = [
          "/proc:/host/proc:ro"
          "/sys:/host/sys:ro"
          "/:/host:ro,rslave"
        ];
        command = [
          "--path.rootfs=/host"
          "--path.procfs=/host/proc"
          "--path.sysfs=/host/sys"
          "--collector.filesystem.mount-points-exclude"
          "^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)"
        ];
        ports = [
          "9100:9100"
        ];
      };
    };
  };
}
