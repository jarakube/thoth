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

## Vault integration (External Secrets Operator)

Set `vault.enabled=true` to source all secrets from vault instead of
values files. The chart creates ExternalSecrets (v1beta1) against the
cluster's `vault-backend` ClusterSecretStore that sync into the SAME
secret names the inline values would create - the pod wiring is
identical either way:

| Secret | Vault path / property (values) | Synced secret |
|---|---|---|
| LLM API key | `vault.llm.key` + `property` | `thoth-llm` (`llm_api_key`) |
| GPG key export | `vault.gpg.key` + `property` | `thoth-gpg` (`gpg-key.asc`) |
| Registry pull | `vault.registry.key` + username/password properties | `thoth-pull` (dockerconfigjson, templated by ESO) |

```yaml
vault:
  enabled: true
  store: {kind: ClusterSecretStore, name: vault-backend}
  refreshInterval: 1h
  llm:
    key: infrastructure/thoth        # vault KV path
    property: LLM_API_KEY
  registry:
    key: infrastructure/thoth
    usernameProperty: REGISTRY_USERNAME
    passwordProperty: REGISTRY_PASSWORD
```

The pull secret is assembled by the ExternalSecret `template`
(ESO go-templating renders the dockerconfigjson from the synced
username/password properties).

Flux note: ExternalSecrets are plain CRs - fully GitOps-compatible;
ESO handles the refresh (`refreshInterval`) so vault-side rotations
reach the pod without redeploying.

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

## Complete example (vault-backed, production-style)

`values.yaml` for a deployment pulling from a private harbor registry
with ALL secrets from vault, rook-ceph storage, and Prometheus
scraping:

```yaml
image:
  repository: pdr-harbor.jarakube.com/jarakube-jaraco/thoth
  tag: "latest"            # or a release tag like v0.1.0

# --- secrets: all from vault (External Secrets Operator) -----------
vault:
  enabled: true
  store:
    kind: ClusterSecretStore
    name: vault-backend
  refreshInterval: 1h
  llm:
    key: infrastructure/thoth          # vault KV path
    property: LLM_API_KEY
  gpg:
    key: infrastructure/thoth
    property: GPG_KEY_ASC              # optional: armored secret key
  registry:
    key: infrastructure/thoth
    usernameProperty: REGISTRY_USERNAME
    passwordProperty: REGISTRY_PASSWORD

imagePullSecret:
  enabled: true
  registry: pdr-harbor.jarakube.com

# --- LLM endpoint (non-secret parts) --------------------------------
llm:
  endpoint: https://litellm.example.com/v1
  models: "mistral-small-latest mistral-large-latest"
  defaultModel: "mistral-large-latest"

gpg:
  trustImported: true                  # ownertrust for the synced key

# --- storage ---------------------------------------------------------
workspace:
  persistence:
    enabled: true
    size: 20Gi
    storageClass: rook-ceph-block

state:
  opencode: {size: 2Gi, storageClass: rook-ceph-block}
  gnupg:    {size: 1Gi, storageClass: rook-ceph-block}
  beads:    {size: 1Gi, storageClass: rook-ceph-block}

metricsData: {size: 1Gi, storageClass: rook-ceph-block}

# --- monitoring -------------------------------------------------------
monitoring:
  serviceMonitor:
    enabled: true                      # requires Prometheus Operator
    interval: 30s

resources:
  requests: {cpu: 100m, memory: 256Mi}
  limits:   {cpu: "2",  memory: 2Gi}
```

```bash
# vault must hold the referenced values, e.g.:
#   vault kv put infrastructure/thoth \
#     LLM_API_KEY=sk-...  GPG_KEY_ASC="-----BEGIN PGP..." \
#     REGISTRY_USERNAME=...  REGISTRY_PASSWORD=...

helm install thoth ./charts/thoth -n thoth --create-namespace -f values.yaml
```

### Post-install verification

```bash
kubectl get pod -n thoth                     # thoth-0  1/1 Running
kubectl logs thoth-0 -n thoth | head -12     # entrypoint chain: beads init,
                                             # LLM key loaded, goosetown clone,
                                             # exporter :9464, MCP registered
helm test thoth -n thoth                     # /metrics answers
kubectl exec -it thoth-0 -n thoth -- bash    # interactive agent shell
kubectl port-forward -n thoth svc/thoth 9464 # local metrics scrape
```

### GitOps (Flux) usage

The chart is Flux-compatible (no lifecycle hooks, plain labels). A
HelmRelease referencing the OCI- or git-sourced chart:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: thoth
  namespace: thoth
spec:
  interval: 10m
  chart:
    spec:
      chart: charts/thoth
      sourceRef:
        kind: GitRepository
        name: thoth-repo          # -> https://github.com/jarakube/thoth
      interval: 10m
  valuesFrom:
    - kind: ConfigMap             # or Secret / values file in the repo
      name: thoth-values
  # values: <inline, or use valuesFrom above>
```

The ExternalSecrets the chart creates are plain CRs - ESO handles
vault refresh, so Flux only manages the chart itself.

## Values reference

See [values.yaml](values.yaml) - every value is documented inline with
its default and its effect. Key groups:

| Group | Controls |
|---|---|
| `image`, `imagePullSecret` | image ref + registry credentials (inline / existingSecret / vault) |
| `vault` | External Secrets Operator integration (store, paths, properties, refresh) |
| `llm`, `gpg` | agent secrets + endpoint/models (inline / existingSecret / vault) |
| `workspace`, `state`, `metricsData` | PVC sizes + storageClasses |
| `config`, `extraEnv` | non-secret env (GOOSE_*, metrics, BEADS_DIR) |
| `podSecurityContext`, `securityContext` | fsGroup 1000 / runAs 1000 (image appuser) |
| `resources`, `service`, `monitoring` | sizing, metrics Service, ServiceMonitor |
