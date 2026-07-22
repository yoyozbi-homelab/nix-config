{ config, pkgs, ... }:
{
  sops.secrets.netbird-setup-key = {
    sopsFile = ./netbird-client-secrets.yml;
  };

  services.netbird = {
    package = pkgs.unstable.netbird;
    clients.default = {
      port = 51820;
      login = {
        enable = true;
        setupKeyFile = config.sops.secrets.netbird-setup-key.path;
        systemdDependencies = [ "sops-install-secrets.service" ];
      };
      config.ManagementURL = "https://netbird.yohanzbinden.ch:443";
    };
  };
}
