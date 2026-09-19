# My personnal nix-config

This respository hosts my servers and desktops nixos configuration
It uses [sops-nix](https://github.com/Mic92/sops-nix) [disko](https://github.com/nix-community/disko) [home-manager](https://github.com/nix-community/home-manager) with flakes
Updates are built by github actions and deployed to servers using cachix-deploy

# Hosts

| Name | location | hardware | role |
| ------ | ---------- | ---------- | ------ |
| ocr1 | oci | arm64 4cpu 24G ram 60G ssd | k3s master |
| tiny1 | oci | amd64 2cpu 1G ram 60G ssd | docker (pangolin manager) |
| tiny2 | oci | amd64 2cpu 1G ram 60G ssd | docker (homelab-wide monitoring: grafana, prometheus, newt) |
| rp | home | rpi4b with 4gb ram | docker (newt, cloudflared, paperless), nightly backups ([restore](hosts/rp/README.md)) |
| ❌ laptop-nix | with me | dell xps16 9520 (i7 12700H 32G ram 1TB ssd) | daily driver |
| ❄️ laptop-omarchy | with me | ⬆️, running omarchy | daily driver |
| ❄️ wsl-nix | with me | ⬆️, running archlinux inside WSL | daily driver |
| surface-nix | with me | Surface Pro 5 | handwritten notes |

❌: Not currently installed or used
❄️: Using `home-manager` only

# Installation (or reinstallation)

## Common

 1. Create a file in `/etc/cachix-agent.token`

 ```
 CACHIX_AGENT_TOKEN=<token>
 ```

 1. Get the new public age key of the server

 ```bash
 nix-shell -p ssh-to-age --run 'ssh-keyscan <ipAdress> | ssh-to-age'
 ```

 1. Change public key of server in `.sops.yaml`
 2. Update keys for secrets

 ```bash
nix-shell -p sops --run "sops updatekeys nixos/_mixins/k3s/ocr-secrets.yml"
 ```

 1. Updates hosts in `hosts.nix`

 2. If the host is a k3s master with argocd, add these to its SOPS file
    (e.g. `hosts/<host>/<host>-sec.yml`). The activation script in
    `nixos/roles/k3s-server.nix` turns them into Kubernetes Secrets on
    every rebuild — nothing is created by hand:

 ```yaml
# ArgoCD's git repository credentials -> Secret argocd-repo-creds in ns argocd,
# labelled argocd.argoproj.io/secret-type: repository
argocd-repo-url: https://github.com/<org>/<repo>
argocd-repo-username: <username, or "git">
argocd-repo-password: <personal access token>

# GitHub webhook shared secret -> key webhook.github.secret in argocd-secret.
# Without it /api/webhook accepts unauthenticated refresh requests.
argocd-webhook-secret: <random string, same value as the GitHub webhook>

# Bitwarden Secrets Manager machine account -> Secret bw-auth-token in ns
# sm-operator-system. Only needed when [network] bitwarden = true.
bws-access-token: <machine account access token>
 ```

 The Bitwarden token is mirrored by [reflector](https://github.com/emberstack/kubernetes-reflector)
 into every namespace labelled `bitwarden-secrets: enabled`. To consume
 secrets in a new namespace, label it and add a `BitwardenSecret` in the
 GitOps repo — no change to this repository is needed:

 ```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
  labels:
    bitwarden-secrets: enabled
---
apiVersion: k8s.bitwarden.com/v1
kind: BitwardenSecret
metadata:
  name: myapp-secrets
  namespace: myapp
spec:
  organizationId: "<org uuid>"
  projectId: "<project uuid>"
  secretName: myapp-secrets
  useSecretNames: true
  onlyMappedSecrets: false
  authToken:
    secretName: bw-auth-token
    secretKey: token
 ```

 1. If the host has  `netdata` run the following command to enroll the node

```bash
sudo netdata-claim.sh
   
```

## For tiny1 or tiny2

 1. Provision a new instance with ubuntu
 2. Connect via ssh and copy `authorized_keys` to the root user
 3. Login with root user
 4. Run the [nixos-infect](https://github.com/elitak/nixos-infect) script:

 ```bash
 curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-24.05 bash -x
 ```

 1. Connect via the root user and change nix-config partitions uuids by looking at the `hardware-configuration.nix` file
 2. Make common modification
 3. Apply custom nix config over the new node

 ```bash
 nixos-rebuild --target-host root@tiny1 --flake ~/nix-config/.#tiny1 switch
 ```

## For rp

1. Build a sd-card image out of the config

```bash
nix build .#nixosConfigurations.rp.config.system.build.images.sd-card  # result/sd-image/*.img.zst
```

1. Make common modifications
1. Add the Bitwarden Secrets Manager machine-account token to `hosts/rp/rp-sec.yml`
   as `bws-access-token`. The `bitwarden-secrets` role uses it at boot to fetch
   the newt credentials and paperless secret key (IDs in `hosts/rp/services.nix`)
   into `/run/bitwarden-secrets`.
