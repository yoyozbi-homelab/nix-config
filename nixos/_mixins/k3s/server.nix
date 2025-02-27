{ config, ... }:
let
  inherit (config.networking.yoyozbi) currentHost;

  rancher = if currentHost.rancher then builtins.readFile ./manifests/rancher.yaml else "";

  traefik-dashboard =
    if currentHost.traefik-dashboard != null && currentHost.traefik-dashboard.enabled then
      builtins.replaceStrings [ "<HOSTNAME>" ] [ currentHost.traefik-dashboard.dashboardUrl ] (
        builtins.readFile ./manifests/traefik.yaml
      )
    else
      "";

  argocd =
    if currentHost.argocd != null && currentHost.argocd.enabled then
      builtins.replaceStrings [ "<HOSTNAME>" ] [ currentHost.argocd.dashboardUrl ] (
        builtins.readFile ./manifests/argocd.yaml
      )
    else
      "";

  longhorn =
    if currentHost.longhorn != null && currentHost.longhorn.enabled then
      builtins.replaceStrings [ "<HOSTNAME>" ] [ currentHost.longhorn.dashboardUrl ] (
        builtins.readFile ./manifests/longhorn.yaml
      )
    else
      "";

  portainer =
    if currentHost.portainer != null && currentHost.portainer.enabled then
      builtins.replaceStrings [ "<HOSTNAME>" ] [ currentHost.portainer.dashboardUrl ] (
        builtins.readFile ./manifests/portainer.yaml
      )
    else
      "";
in
{
  imports = [ ./. ];

  services.k3s = {
    enable = false; # Disable the service to remove k3s data
    role = "server";
    extraFlags = toString [
      "--node-external-ip=${currentHost.externalIp}"
      "--node-ip=${currentHost.internalIp}"
      "--advertise-address=${currentHost.internalIp}"
    ];
    tokenFile = config.sops.secrets.k3s-server-token.path;
    clusterInit = true;
  };

  environment.etc."k3s.yaml".text = builtins.readFile ./manifests/default.yaml;
  environment.etc."rancher.yaml".text = rancher;
  environment.etc."traefik-dashboard.yaml".text = traefik-dashboard;
  environment.etc."argocd.yaml".text = argocd;
  environment.etc."longhorn.yaml".text = longhorn;
  environment.etc."portainer.yaml".text = portainer;

  # Link the file to k3s manifest directory
  system.activationScripts.k3s.text = ''
       mkdir -p /var/lib/rancher/k3s/server/manifests
       ln -sf /etc/k3s.yaml /var/lib/rancher/k3s/server/manifests/init.yaml

       if [ -s /etc/rancher.yaml ]; then
    ln -sf /etc/rancher.yaml /var/lib/rancher/k3s/server/manifests/rancher.yaml
       fi

    if [ -s /etc/traefik-dashboard.yaml ]; then
    	ln -sf /etc/traefik-dashboard.yaml /var/lib/rancher/k3s/server/manifests/traefik-dashboard.yaml
    fi

    if [ -s /etc/argocd.yaml ]; then
    	ln -sf /etc/argocd.yaml /var/lib/rancher/k3s/server/manifests/argocd.yaml
    fi

    if [ -s /etc/longhorn.yaml ]; then
    	ln -sf /etc/longhorn.yaml /var/lib/rancher/k3s/server/manifests/longhorn.yaml
    fi

    if [ -s /etc/portainer.yaml ]; then
    	ln -sf /etc/portainer.yaml /var/lib/rancher/k3s/server/manifests/portainer.yaml
    fi
  '';
}
