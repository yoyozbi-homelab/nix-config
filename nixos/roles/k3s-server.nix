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

        # GitHub webhook shared secret. Without it ArgoCD's /api/webhook accepts
        # unauthenticated payloads and refreshes apps on every request, a cheap
        # amplification vector on a publicly exposed instance. With it, ArgoCD
        # verifies the X-Hub-Signature-256 HMAC and drops everything else.
        #
        # This adds one key to argocd-secret, which the argo-cd chart also owns.
        # The Helm ownership labels/annotations are mandatory: on a fresh install
        # this manifest lands before helm-controller runs, and Helm aborts on a
        # pre-existing resource it cannot prove it owns. With them it adopts the
        # Secret instead.
        #
        # Our key then survives upgrades because the chart emits argocd-secret with
        # no data: field while every configs.secret.* value is empty, so helm never
        # reconciles data — the same reason ArgoCD's own server.secretkey and
        # admin.password survive. Kept out of valuesContent so the shared secret
        # never reaches the world-readable nix store.
        if [ -f /run/secrets/argocd-webhook-secret ]; then
          webhook=$(printf '%s' "$(cat /run/secrets/argocd-webhook-secret)" | base64 -w 0)

          cat > "$manifests/argocd-webhook-secret.yaml" <<EOF
        apiVersion: v1
        kind: Secret
        metadata:
          name: argocd-secret
          namespace: argocd
          labels:
            app.kubernetes.io/managed-by: Helm
          annotations:
            meta.helm.sh/release-name: argocd
            meta.helm.sh/release-namespace: argocd
        type: Opaque
        data:
          webhook.github.secret: $webhook
        EOF
          chmod 600 "$manifests/argocd-webhook-secret.yaml"
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

          # Bootstrap "app of apps". ArgoCD does not scan registered repos, so this
          # is the one Application that cannot live in the GitOps repo itself: it is
          # what discovers everything that does. Every application.yaml committed
          # under the repo root is picked up from here.
          #
          # It reads the same secret as the credential above, so the two URLs cannot
          # drift — a mismatch would stop ArgoCD associating argocd-repo-creds with
          # this source.
          cat > "$manifests/argocd-root-app.yaml" <<EOF
        apiVersion: argoproj.io/v1alpha1
        kind: Application
        metadata:
          name: root
          namespace: argocd
          finalizers:
            - resources-finalizer.argocd.argoproj.io
        spec:
          project: default
          source:
            repoURL: $(cat /run/secrets/argocd-repo-url)
            targetRevision: main
            path: .
            directory:
              recurse: true
              # Only the per-app Application manifests. Without this the root app
              # also renders every */manifests/ file, so each child app's resources
              # end up owned by both root and the dedicated app (SharedResourceWarning).
              # Two patterns: ArgoCD has matched this glob against the base name in
              # some versions and the repo-relative path in others.
              include: '{application.yaml,*/application.yaml}'
          destination:
            server: https://kubernetes.default.svc
            namespace: argocd
          syncPolicy:
            automated:
              prune: true
              selfHeal: true
            syncOptions:
              - CreateNamespace=true
        EOF
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
