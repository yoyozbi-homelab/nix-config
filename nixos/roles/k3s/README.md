# K3s cluster setup

`ocr1` runs a cluster, `rp` runs another one.

## Phone access (read-only + pod restart)

The `phone-access` ServiceAccount in `kube-system` gives read-only cluster access
plus the ability to delete/restart pods and trigger rolling restarts on workloads.
It is deployed automatically via the k3s manifest auto-apply directory.

### Retrieve the bearer token

Run on `ocr1` (or any machine with `kubectl` and a valid kubeconfig):

```bash
kubectl get secret phone-access-token -n kube-system \
  -o jsonpath='{.data.token}' | base64 -d
```

Use this token as the Bearer token in your phone app's kubeconfig or connection
settings, pointed at `https://ocr1.netbird.selfhosted:6443`.

### Generate a kubeconfig

Run this on any machine that already has cluster access to produce a ready-to-use
`phone-access.kubeconfig`:

```bash
kubectl get secret phone-access-token -n kube-system -o go-template='
apiVersion: v1
kind: Config
clusters:
  - name: ocr1
    cluster:
      server: https://ocr1.netbird.selfhosted:6443
      certificate-authority-data: {{ index .data "ca.crt" }}
contexts:
  - name: phone-access@ocr1
    context:
      cluster: ocr1
      user: phone-access
current-context: phone-access@ocr1
users:
  - name: phone-access
    user:
      token: {{ .data.token | base64decode }}
' > phone-access.kubeconfig
```

Copy `phone-access.kubeconfig` to your phone app (Lens, k9s, Portainer Mobile, etc.).

### Permissions summary

| Action | Scope |
| --- | --- |
| get / list / watch all resources | cluster-wide (via built-in `view` role) |
| delete pods | cluster-wide |
| patch / update deployments, statefulsets, daemonsets | cluster-wide |
