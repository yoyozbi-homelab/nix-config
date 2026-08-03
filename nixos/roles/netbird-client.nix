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
      # Config.ManagementURL is a *url.URL on disk, so it must be serialised as
      # an object -- a plain string fails to unmarshal (netbird >= 0.74).
      config.ManagementURL = {
        Scheme = "https";
        Host = "netbird.yohanzbinden.ch:443";
      };
    };
  };
}
