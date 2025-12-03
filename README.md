# My personnal nix-config

This respository hosts my servers and desktops nixos configuration
It uses [sops-nix](https://github.com/Mic92/sops-nix) [disko](https://github.com/nix-community/disko) [home-manager](https://github.com/nix-community/home-manager) with flakes
Updates are built by github actions and deployed to servers using cachix-deploy

# Hosts

| Name | location | hardware | role |
|------|----------|----------|------|
| ocr1 | oci      | arm64 4cpu 24G ram 60G ssd | k3s master |
| tiny1 | oci     | amd64 2cpu 1G ram 60G ssd  | k3s agent  |
| tiny2 | oci     | amd64 2cpu 1G ram 60G ssd  | k3s agent  |
| rp    | home    | rpi4b with 4gb ram         | k3s cluster (solo)  |
| laptop-nix | with me | dell xps16 9520 (i7 12700H 32G ram 1TB ssd) | daily driver |
| surface-nix | with me | Surface Pro 5 | handwritten notes |

# Installation (or reinstallation)

## Common

 1. Create a file in `/etc/cachix-agent.token`

 ```
 CACHIX_AGENT_TOKEN=<token>
 ```

 2. Get the new public age key of the server

 ```bash
 nix-shell -p ssh-to-age --run 'ssh-keyscan <ipAdress> | ssh-to-age'
 ```

 3. Change public key of server in `.sops.yaml`
 4. Update keys for secrets

 ```bash
nix-shell -p sops --run "sops updatekeys nixos/_mixins/k3s/ocr-secrets.yml"
 ```

 5. Updates hosts in `hosts.nix`

 6. If the host is a k3s master with argocd:
 ```bash
# Create argocd namespace if it doesn't exist
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Convert SSH host key to age private key
nix-shell -p ssh-to-age --run 'ssh-to-age -private-key -i /root/.ssh/ssh_host_ed25519_key' > age.key

# Create the secret
kubectl create secret generic sops-age \
  --namespace=argocd \
  --from-file=keys.txt=age.key

# Clean up the temporary file
rm age.key
 ```

 6. If the host has  `netdata` run the following command to enroll the node

```bash
sudo netdata-claim.sh
   
```

## For tiny1 or tiny2

 1. Provision a new instance with ubuntu
 2. Connect via ssh and copy `authorized_keys` to the root user
 3. Login with root user
 4. Run the [nixos-infect](https://github.com/elitak/nixos-infect) script:

 ```bash
 curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-23.05 bash -x
 ```

 5. Connect via the root user and change nix-config partitions uuids by looking at the `hardware-configuration.nix` file
 6. Make common modification
 7. Apply custom nix config over the new node

 ```bash
 nixos-rebuild --target-host root@tiny1 --flake ~/nix-config/.#tiny1 switch
 ```

## For rp

1. Build a sd-card image out of the config

```bash
nix run nixpkgs#nixos-generators -- -f sd-aarch64 --flake .#rp --system aarch64-linux -o ../pi.sd
```

2. Make common modifications
