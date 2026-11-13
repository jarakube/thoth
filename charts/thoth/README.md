# thoth Helm chart

Deploys the [thoth](https://github.com/jarakube/thoth) agent container
(OpenCode + goose/goosetown + kubectl) to Kubernetes. One thoth per
namespace: a single-replica StatefulSet with PVC-backed state.

## Install

```bash
helm install thoth ./charts/thoth -n thoth --create-namespace \
  --set imagePullSecret.username=YOUR_REGISTRY_USER \
  --set imagePullSecret.password=YOUR_REGISTRY_PASS \
  --set llm.endpoint=https://litellm.example.com/v1 \
  --set llm.apiKey=sk-...
```

Or with a values file (recommended for real deployments):

```yaml
image:
  repository: pdr-harbor.jarakube.com/jarakube-jaraco/thoth
  tag: "latest"

imagePullSecret:
  enabled: true
  username: ...
  password: ...

llm:
  endpoint: https://litellm.example.com/v1
  apiKey: ...          # or existingSecret: my-llm-secret

workspace:
  persistence:
    size: 20Gi
    storageClass: rook-ceph-block

state:
  opencode: {size: 2Gi, storageClass: rook-ceph-block}
  gnupg:    {size: 1Gi, storageClass: rook-ceph-block}
  beads:    {size: 1Gi, storageClass: rook-ceph-block}

monitoring:
  serviceMonitor:
    enabled: true       # requires Prometheus Operator CRDs
```

## What gets deployed

| Resource | Purpose |
|---|---|
| StatefulSet (1 replica) | The thoth container; entrypoint sets up LLM key, gpg, beads, MCP, metrics |
| PVCs: workspace / opencode / gnupg / beads / metrics | Independent state lifecycles; all sizes and storageClasses configurable |
| Secret (pull) | Created from `imagePullSecret` values when set |
| Secret (llm / gpg) | Created from `llm.apiKey` / `gpg.importKey` when set; `existingSecret` alternatives |
| ConfigMap (env) | Non-secret agent config (GOOSE_*, metrics, ...) |
| Service :9464 | Metrics endpoint (the container's Prometheus exporter) |
| ServiceMonitor (optional) | For Prometheus Operator scraping |
| helm test pod | `helm test` verifies /metrics answers |

## Notes

- **Flux compatible**: no Helm lifecycle hooks except the standard
  `helm.sh/hook: test` on the test pod; plain labels; no CRD deps
  (ServiceMonitor is opt-in).
- The LLM key mounts as a **subPath file** at `/run/secrets/llm_api_key`
  (same path as the compose secret) - mounting the whole `/run/secrets`
  would shadow the kubelet's projected serviceaccount tokens.
- `args` (not `command`) keeps the image entrypoint running - it starts
  the metrics exporter the probes and `helm test` rely on.
- `fsGroup: 1000` makes the PVCs writable by the image's appuser.
- Verified live: pod 1/1 Ready, agents functional, state persists
  across pod deletion, metrics scrapeable via the Service.
