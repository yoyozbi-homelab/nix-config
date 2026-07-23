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
settings, pointed at `https://<ocr1-external-ip>:6443`.

### Permissions summary

| Action | Scope |
| --- | --- |
| get / list / watch all resources | cluster-wide (via built-in `view` role) |
| delete pods | cluster-wide |
| patch / update deployments, statefulsets, daemonsets | cluster-wide |
