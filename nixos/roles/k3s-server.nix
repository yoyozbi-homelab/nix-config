{ config, ... }:
let
  inherit (config.networking.yoyozbi) currentHost;

  rancher = if currentHost.rancher then builtins.readFile ./k3s/manifests/rancher.yaml else "";

  traefik-dashboard =
    if currentHost.traefik-dashboard != null && currentHost.traefik-dashboard.enabled then
      builtins.replaceStrings [ "<HOSTNAME>" ] [ currentHost.traefik-dashboard.dashboardUrl ] (
        builtins.readFile ./k3s/manifests/traefik.yaml
      )
    else
      "";

  argocd =
    if currentHost.argocd != null && currentHost.argocd.enabled then
      builtins.replaceStrings [ "<HOSTNAME>" ] [ currentHost.argocd.dashboardUrl ] (
        builtins.readFile ./k3s/manifests/argocd.yaml
      )
    else
      "";

  longhorn =
    if currentHost.longhorn != null && currentHost.longhorn.enabled then
      builtins.replaceStrings [ "<HOSTNAME>" ] [ currentHost.longhorn.dashboardUrl ] (
        builtins.readFile ./k3s/manifests/longhorn.yaml
      )
    else
      "";

  portainer =
    if currentHost.portainer != null && currentHost.portainer.enabled then
      builtins.replaceStrings [ "<HOSTNAME>" ] [ currentHost.portainer.dashboardUrl ] (
        builtins.readFile ./k3s/manifests/portainer.yaml
      )
    else
      "";

  flux =
    if currentHost.flux != null && currentHost.flux.enabled then
      builtins.replaceStrings [ "<HOSTNAME>" ] [ currentHost.flux.dashboardUrl ] (
        builtins.readFile ./k3s/manifests/flux.yaml
      )
    else
      "";

in
{
  imports = [ ./k3s ];

  services.k3s = {
    role = "server";
    extraFlags = toString (
      [
        "--node-external-ip=${currentHost.externalIp}"
        "--node-ip=${currentHost.internalIp}"
        "--advertise-address=${currentHost.internalIp}"
        "--tls-san=${currentHost.externalIp}"
      ]
      ++ map (san: "--tls-san=${san}") currentHost."tls-sans"
    );
    tokenFile = config.sops.secrets.k3s-server-token.path;
    clusterInit = true;
  };

  environment.etc."k3s.yaml".text = builtins.readFile ./k3s/manifests/default.yaml;
  environment.etc."rancher.yaml".text = rancher;
  environment.etc."traefik-dashboard.yaml".text = traefik-dashboard;
  environment.etc."argocd.yaml".text = argocd;
  environment.etc."longhorn.yaml".text = longhorn;
  environment.etc."portainer.yaml".text = portainer;
  environment.etc."flux.yaml".text = flux;

  # Write cloudflared token as a k8s Secret manifest from the SOPS-decrypted secret.
  # The official cloudflared image is distroless (no /bin/sh), so shell substitution
  # to read a hostPath file doesn't work — TUNNEL_TOKEN env var is used instead.
  system.activationScripts.cloudflaredSecret = {
    deps = [
      "setupSecrets"
      "k3s"
    ];
    text = ''
      if [ -f /run/secrets/cloudflared-token ]; then
        token=$(cat /run/secrets/cloudflared-token)
        encoded=$(printf '%s' "$token" | base64 -w 0)
        printf 'apiVersion: v1\nkind: Secret\nmetadata:\n  name: cloudflared-token\n  namespace: kube-system\ntype: Opaque\ndata:\n  token: %s\n' \
          "$encoded" > /var/lib/rancher/k3s/server/manifests/cloudflared-secret.yaml
        chmod 600 /var/lib/rancher/k3s/server/manifests/cloudflared-secret.yaml
      fi
    '';
  };

  # Link the file to k3s manifest directory
  environment.etc."phone-access.yaml".text = builtins.readFile ./k3s/manifests/phone-access.yaml;

  system.activationScripts.k3s.text = ''
       mkdir -p /var/lib/rancher/k3s/server/manifests
       ln -sf /etc/k3s.yaml /var/lib/rancher/k3s/server/manifests/init.yaml
       ln -sf /etc/phone-access.yaml /var/lib/rancher/k3s/server/manifests/phone-access.yaml

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

    if [ -s /etc/flux.yaml ]; then
    	ln -sf /etc/flux.yaml /var/lib/rancher/k3s/server/manifests/flux.yaml
    fi
  '';
}
