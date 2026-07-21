{ config, ... }:
{
  sops.secrets.netbird-setup-key = {
    sopsFile = ./netbird-client-secrets.yml;
  };

  services.netbird.clients.default = {
    login.enable = true;
    login.setupKeyFile = config.sops.secrets.netbird-setup-key.path;
    login.systemdDependencies = [ "sops-install-secrets.service" ];
    config.ManagementURL = "https://netbird.yohanzbinden.ch";
  };
}
