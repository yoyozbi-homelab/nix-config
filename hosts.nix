# based on https://github.com/TUM-DSE/doctor-cluster-config/blob/master/modules/hosts.nix
{
  lib,
  config,
  hostname,
  desktop,
  ...
}:
let
  traefikOptions = lib.types.submodule {
    options = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable traefik dashboard
        '';
      };
      dashboardUrl = lib.mkOption {
        type = lib.types.str;
        default = "traefik.${hostname}.local";
        description = ''
          Url of the traefik dashboard
        '';
      };
    };
  };

  longhornOptions = lib.types.submodule {
    options = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable longhorn helm chart (only for master nodes)
        '';
      };
      dashboardUrl = lib.mkOption {
        type = lib.types.str;
        default = "longhorn.${hostname}.local";
        description = ''
          URL of the dashboard
        '';
      };
    };
  };

  argocdOptions = lib.types.submodule {
    options = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable argocd helm chart (only for master nodes)
        '';
      };
      dashboardUrl = lib.mkOption {
        type = lib.types.str;
        default = "argocd.${hostname}.local";
      };
    };
  };

  portainerOptions = lib.types.submodule {
    options = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable portainer helm chart (only for master nodes)
        '';
      };
      dashboardUrl = lib.mkOption {
        type = lib.types.str;
        default = "portainer.${hostname}.local";
      };
    };
  };

  hostOptions = with lib; {
    internalIp = mkOption {
      type = types.str;
      description = ''
        own internal ipv4 address
      '';
    };
    externalIp = mkOption {
      type = types.str;
      description = ''
        own external ipv4 address
      '';
    };

    mac = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        MAC address of the NIC port used as a gateway
      '';
    };
    rancher = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If this is a k3s server specify if you want to install rancher or not
      '';
    };

    traefik-dashboard = mkOption {
      type = types.nullOr traefikOptions;
      default = null;
      description = ''
        Traefik dashboard configuration
      '';
    };

    portainer = mkOption {
      type = types.nullOr portainerOptions;
      default = null;
      description = ''
        portainer config
      '';
    };

    argocd = mkOption {
      type = types.nullOr argocdOptions;
      default = null;
      description = ''
        argocd config
      '';
    };

    longhorn = mkOption {
      type = types.nullOr longhornOptions;
      default = null;
      description = ''
        longhorn configuration
      '';
    };
  };
in
{
  options = with lib; {
    networking.yoyozbi.hosts = mkOption {
      type = with types; attrsOf (submodule [ { options = hostOptions; } ]);
      description = "A host in the cluster";
    };
    networking.yoyozbi.currentHost = mkOption {
      type = with types; submodule [ { options = hostOptions; } ];
      default = config.networking.yoyozbi.hosts.${hostname};
      description = "The host that is described by this configuration";
    };
  };
  config = {
    warnings = lib.optional (
      !(config.networking.yoyozbi.hosts ? ${hostname}) && desktop == null # we dont care if it is not a server
    ) "Please add network configuration for ${hostname}. None found in ${./hosts.nix}";

    networking.yoyozbi.hosts = {
      ocr1 = {
        internalIp = "10.0.0.93";
        externalIp = "144.24.253.246";
        mac = "02:00:17:00:a1:bb";
        traefik-dashboard = {
          enabled = true;
          dashboardUrl = "traefik-ocr1.yohanzbinden.ch";
        };

        argocd = {
          enabled = true;
          dashboardUrl = "argocd.yohanzbinden.ch";
        };

        portainer = {
          enabled = true;
          dashboardUrl = "portainer.yohanzbinden.ch";
        };

        longhorn = {
          enabled = true;
          dashboardUrl = "longhorn.yohanzbinden.ch";
        };
      };

      tiny1 = {
        internalIp = "10.0.0.127";
        externalIp = "132.226.223.75";
        mac = "02:00:17:00:71:87";
      };

      tiny2 = {
        internalIp = "10.0.0.84";
        externalIp = "152.67.67.251";
        mac = "02:00:17:00:a3:d4";
      };

      rp = {
        internalIp = "192.168.1.2";
        mac = "dc:a6:32:21:28:99";
        externalIp = "192.168.1.2";

        traefik-dashboard = {
          enabled = true;
          dashboardUrl = "traefik-rp.yohanzbinden.ch";
        };

        argocd = {
          enabled = true;
          dashboardUrl = "argo-rp.yohanzbinden.ch";
        };
      };
    };
  };
}
