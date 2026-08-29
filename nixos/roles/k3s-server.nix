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

  bitwarden-sm-operator =
    if currentHost.bitwarden then builtins.readFile ./k3s/manifests/bitwarden-sm-operator.yaml else "";

  reflector = if currentHost.bitwarden then builtins.readFile ./k3s/manifests/reflector.yaml else "";

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
  environment.etc = {

    "k3s.yaml".text = builtins.readFile ./k3s/manifests/default.yaml;
    "rancher.yaml".text = rancher;
    "traefik-dashboard.yaml".text = traefik-dashboard;
    "argocd.yaml".text = argocd;
    "longhorn.yaml".text = longhorn;
    "portainer.yaml".text = portainer;
    "flux.yaml".text = flux;
    "bitwarden-sm-operator.yaml".text = bitwarden-sm-operator;
    "reflector.yaml".text = reflector;

    # Link the file to k3s manifest directory
    "phone-access.yaml".text = builtins.readFile ./k3s/manifests/phone-access.yaml;
  };
  system.activationScripts = {

    cloudflaredSecret = {

      # Write cloudflared token as a k8s Secret manifest from the SOPS-decrypted secret.
      # The official cloudflared image is distroless (no /bin/sh), so shell substitution
      # to read a hostPath file doesn't work — TUNNEL_TOKEN env var is used instead.

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

    # Seed the two Secrets that can't live in a manifest, since manifests go
    # through the nix store: ArgoCD's git repo credentials and the Bitwarden
    # Secrets Manager machine-account token. Same approach as cloudflaredSecret.
    #
    # The bw-auth-token annotations tell reflector to mirror the token into
    # every namespace labelled bitwarden-secrets=enabled, so the GitOps repo
    # can add namespaces without touching nix-config.
    bitwardenSecrets = {
      deps = [
        "setupSecrets"
        "k3s"
      ];
      text = ''
        manifests=/var/lib/rancher/k3s/server/manifests

        if [ -f /run/secrets/bws-access-token ]; then
          token=$(printf '%s' "$(cat /run/secrets/bws-access-token)" | base64 -w 0)

          cat > "$manifests/bw-auth-token.yaml" <<EOF
        apiVersion: v1
        kind: Secret
        metadata:
          name: bw-auth-token
          namespace: sm-operator-system
          annotations:
            reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
            reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces-selector: "bitwarden-secrets=enabled"
            reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
            reflector.v1.k8s.emberstack.com/reflection-auto-namespaces-selector: "bitwarden-secrets=enabled"
        type: Opaque
        data:
          token: $token
        EOF
          chmod 600 "$manifests/bw-auth-token.yaml"
        fi

        if [ -f /run/secrets/argocd-repo-url ] \
          && [ -f /run/secrets/argocd-repo-username ] \
          && [ -f /run/secrets/argocd-repo-password ]; then
          gitType=$(printf '%s' git | base64 -w 0)
          url=$(printf '%s' "$(cat /run/secrets/argocd-repo-url)" | base64 -w 0)
          username=$(printf '%s' "$(cat /run/secrets/argocd-repo-username)" | base64 -w 0)
          password=$(printf '%s' "$(cat /run/secrets/argocd-repo-password)" | base64 -w 0)

          cat > "$manifests/argocd-repo-creds.yaml" <<EOF
        apiVersion: v1
        kind: Secret
        metadata:
          name: argocd-repo-creds
          namespace: argocd
          labels:
            argocd.argoproj.io/secret-type: repository
        type: Opaque
        data:
          type: $gitType
          url: $url
          username: $username
          password: $password
        EOF
          chmod 600 "$manifests/argocd-repo-creds.yaml"
        fi
      '';
    };

    k3s.text = ''
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

      if [ -s /etc/bitwarden-sm-operator.yaml ]; then
      	ln -sf /etc/bitwarden-sm-operator.yaml /var/lib/rancher/k3s/server/manifests/bitwarden-sm-operator.yaml
      fi

      if [ -s /etc/reflector.yaml ]; then
      	ln -sf /etc/reflector.yaml /var/lib/rancher/k3s/server/manifests/reflector.yaml
      fi
    '';
  };
}
