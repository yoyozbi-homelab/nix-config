# NetBird self-hosted setup

Stack: Traefik + NetBird Server + Dashboard + Reverse Proxy + CrowdSec.

## First deploy

The proxy container crash-loops on the first deploy — that is expected.
Two secrets must be provisioned after the stack is running before rebuilding:

### 1. Generate the proxy token

Run on `tiny1` after the first `nixos-rebuild switch`:

```bash
docker compose -p netbird exec -T netbird-server \
  /go/bin/netbird-server token create --name default-proxy \
  --config /etc/netbird/config.yaml | awk '/^Token:/{print $2}'
```

Copy the printed token into `netbird-secrets.yml` as `netbird-proxy-token`:

```bash
sops nixos/roles/docker/netbird-secrets.yml
```

### 2. Register the CrowdSec bouncer

The bouncer key is already pre-generated in sops. Register it with the running
CrowdSec container so it matches what `proxy.env` sends:

```bash
docker exec netbird-crowdsec cscli bouncers add netbird-proxy \
  -k "$(sops -d --extract '["netbird-crowdsec-bouncer-key"]' \
        nixos/roles/docker/netbird-secrets.yml)"
```

### 3. Rebuild

```bash
nixos-rebuild --target-host root@tiny1 --flake .#tiny1 switch
```

The proxy container should now start cleanly.

## Rotating the setup key (host reinstall or key expiry)

All hosts using the `netbird-client` role (`tiny1`, `tiny2`, `ocr1`, `rp`,
`laptop-nix`) share a single setup key stored in
`nixos/roles/netbird-client-secrets.yml`.

### 1. Delete stale peers (reinstall only)

In the NetBird dashboard → **Peers**, delete the old peer entry for the
reinstalled host. Otherwise the host will register as a duplicate.

### 2. Generate a new setup key

In the NetBird dashboard → **Setup Keys**, create a new reusable key (or
invalidate the old one and create a replacement).

### 3. Update the secret

```bash
sops nixos/roles/netbird-client-secrets.yml
```

Replace the value of `netbird-setup-key` with the new key.

### 4. Rebuild all affected hosts

```bash
nixos-rebuild --target-host root@tiny1  --flake .#tiny1  switch
nixos-rebuild --target-host root@tiny2  --flake .#tiny2  switch
nixos-rebuild --target-host root@ocr1   --flake .#ocr1   switch
nixos-rebuild --target-host root@rp     --flake .#rp     switch
```

`laptop-nix` picks it up on the next local `nixos-rebuild switch`.

Each host restarts its `netbird` service on activation and re-registers with
the new key.

## External prerequisites

- DNS: `A netbird.yohanzbinden.ch → 144.24.255.32` and `CNAME *.netbird.yohanzbinden.ch → netbird.yohanzbinden.ch`
- OCI security list ingress: TCP 80, TCP 443, UDP 3478, UDP 51820
