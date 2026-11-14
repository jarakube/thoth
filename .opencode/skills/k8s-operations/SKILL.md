---
name: k8s-operations
description: Comprehensive Kubernetes operations management for the jaraco k8s-operations project. Handles Flux CD deployments, Istio service mesh (Gateways, VirtualServices), Vault integration, External Secrets, MetalLB, cert-manager, and multi-cluster management.
---


# Kubernetes Operations Skill


## OVERVIEW

This skill provides specialized assistance for managing the jaraco Kubernetes operations project, which includes:

- **GitOps with Flux CD** - Automated deployments from Git repositories
- **Service Mesh with Istio** - Gateways, VirtualServices, and traffic management
- **Secrets Management with Vault** - Secure secrets storage with auto-unseal and OIDC integration
- **External Secrets Operator** - Sync secrets from Vault to Kubernetes
- **Ingress Management** - MetalLB load balancing and TLS termination
- **Certificate Management** - cert-manager for automatic TLS certificates
- **Multi-Cluster Management** - Support for jarakube cluster and namespaces
- **Observability** - Loki, Grafana, Prometheus monitoring stack
- **Storage** - Rook Ceph for persistent storage

---

## CAPABILITIES

### Flux CD Management
- Deploy and manage Flux CD components
- Configure GitRepository sources
- Create and manage Kustomization resources
- Sync cluster state from Git
- Troubleshoot Flux reconciliation issues
- Manage HelmRepository sources
- Promote applications between environments (develop, production)

### Istio Service Mesh
- Create and manage Gateways (external, internal)
- Configure VirtualServices for application routing
- Set up TLS termination and HTTPS redirection
- Manage ingress and egress gateways
- Configure service mesh logging and observability
- Set up cross-namespace service communication

### Vault Integration
- Deploy and configure Vault with HA Raft storage
- Set up Vault auto-unseal with Shamir's secret sharing
- Configure Vault OIDC authentication with Keycloak
- Create Vault policies and roles
- Manage Vault secrets engines (KV v2)
- Configure Vault certificate authority
- Set up Vault VirtualServices for secure access

### External Secrets
- Configure ClusterSecretStore for Vault backend
- Create ExternalSecret resources for applications
- Manage secret synchronization from Vault to Kubernetes
- Configure secret refresh intervals
- Set up namespace-specific secret stores

### Networking
- Configure MetalLB for load balancing
- Set up IP address pools for ingress
- Manage DNS configuration
- Configure network policies
- Set up service mesh egress gateways

### Certificate Management
- Configure cert-manager ClusterIssuers
- Create and manage TLS certificates
- Set up automatic certificate renewal
- Configure wildcard certificates for domains

### Application Deployment
- Deploy applications to develop and production namespaces
- Create VirtualServices for application routing
- Configure service discovery and load balancing
- Manage application secrets and configurations
- Set up health checks and monitoring

---

## USAGE EXAMPLES

### Flux CD Operations

**Deploy a new application with Flux:**
```
USE: deploy flux application
WITH: name=my-app, namespace=develop, git-repo=https://github.com/jaraco/my-app, path=./manifests, interval=5m
```

**Check Flux sync status:**
```
USE: check flux sync status
WITH: namespace=flux-system
```

**Troubleshoot Flux reconciliation:**
```
USE: troubleshoot flux reconciliation
WITH: kustomization=my-app, namespace=develop
```

### Istio Service Mesh

**Create a new Gateway:**
```
USE: create istio gateway
WITH: name=my-gateway, namespace=istio-ingress-internal, hosts=["*.my-domain.com"], tls=simple, certificate=my-tls-cert
```

**Create a VirtualService for an application:**
```
USE: create virtualservice
WITH: name=my-app-vs, namespace=develop, hosts=["my-app.jarakube.com"], gateway=jarakube-com-internal-shared-gateway, service=my-app-service, port=80
```

**Configure HTTPS redirection:**
```
USE: configure https redirect
WITH: gateway=my-gateway, namespace=istio-ingress-internal, hosts=["*.my-domain.com"]
```

### Vault Operations

**Deploy Vault with HA Raft storage:**
```
USE: deploy vault
WITH: namespace=vault, storage_class=rook-ceph-block, storage_size=15Gi, ha_enabled=true, ui_enabled=true
```

**Configure Vault auto-unseal:**
```
USE: configure vault auto-unseal
WITH: namespace=vault, schedule="*/10 * * * *", unseal_key_secret=vault-unseal-key
```

**Set up Vault OIDC with Keycloak:**
```
USE: setup vault oidc
WITH: vault_namespace=vault, keycloak_realm=jaraco, keycloak_url=https://keycloak.jarakube.com, client_id=vault
```

**Create a new secret in Vault:**
```
USE: create vault secret
WITH: path=kv/jaraco/dev, key=my-app, secret_data={"username":"admin","password":"secret123"}
```

### External Secrets

**Create a ClusterSecretStore for Vault:**
```
USE: create secret store
WITH: name=vault-backend, vault_server=http://vault.vault.svc.cluster.local:8200, vault_path=kv/jaraco, auth_method=token, token_secret=vault-token
```

**Create an ExternalSecret for an application:**
```
USE: create external secret
WITH: name=my-app-secret, namespace=develop, secret_store=vault-backend, refresh_interval=60m, data=[{"key":"dev","property":"db-password","secret_key":"db-password"}]
```

### Networking

**Configure MetalLB IP pool:**
```
USE: configure metallb pool
WITH: name=ingress-pool, namespace=metallb-system, addresses=["192.168.178.121/32"], auto_assign=true
```

**Create a LoadBalancer service:**
```
USE: create loadbalancer service
WITH: name=my-service, namespace=develop, ports=[{"port":80,"targetPort":8080}], loadbalancer_ip=192.168.178.121
```

### Certificate Management

**Create a wildcard certificate:**
```
USE: create wildcard certificate
WITH: name=jarakube-wildcard-tls, namespace=istio-ingress-external, domains=["*.jarakube.com"], issuer=letsencrypt-prod
```

**Configure cert-manager ClusterIssuer:**
```
USE: configure cluster issuer
WITH: name=letsencrypt-prod, issuer_type=ACME, server=https://acme-v02.api.letsencrypt.org/directory, email=admin@jarakube.com
```

---

## COMMANDS

### Flux CD Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| `flux bootstrap` | Bootstrap Flux CD in a cluster | git_repository, branch, path, network_policy |
| `flux reconcile` | Force reconciliation of Flux resources | namespace, kustomization |
| `flux get sources` | List all Flux GitRepository and HelmRepository sources | namespace |
| `flux get kustomizations` | List all Flux Kustomization resources | namespace |
| `flux suspend` | Suspend Flux reconciliation | namespace, kustomization |
| `flux resume` | Resume Flux reconciliation | namespace, kustomization |
| `flux export` | Export Flux manifests | namespace, output_file |
| `flux check` | Check Flux installation and health | namespace |

### Istio Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| `istio install` | Install Istio components | profile, namespace, values_file |
| `istio gateway create` | Create a new Gateway resource | name, namespace, hosts, tls_mode, certificate |
| `istio virtualservice create` | Create a new VirtualService resource | name, namespace, hosts, gateway, destination |
| `istio gateway list` | List all Gateway resources | namespace |
| `istio virtualservice list` | List all VirtualService resources | namespace |
| `istio analyze` | Analyze Istio configuration for issues | namespace |
| `istio version` | Check Istio version | namespace |

### Vault Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| `vault deploy` | Deploy Vault with Helm | namespace, values_file, storage_class |
| `vault init` | Initialize Vault | namespace |
| `vault unseal` | Unseal Vault | namespace, unseal_key |
| `vault login` | Login to Vault | namespace, token |
| `vault secret create` | Create a new secret | path, key, data |
| `vault secret read` | Read a secret | path, key |
| `vault policy create` | Create a new policy | name, policy_file |
| `vault auth enable` | Enable auth method | method, path |
| `vault oidc configure` | Configure OIDC auth | discovery_url, client_id, client_secret |

### External Secrets Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| `external-secret create store` | Create a ClusterSecretStore | name, provider, auth |
| `external-secret create` | Create an ExternalSecret | name, namespace, store, data |
| `external-secret list` | List all ExternalSecrets | namespace |
| `external-secret status` | Check ExternalSecret sync status | name, namespace |
| `external-secret refresh` | Force refresh of ExternalSecret | name, namespace |

### Networking Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| `metallb configure` | Configure MetalLB | config_file |
| `metallb pool create` | Create IP address pool | name, addresses, auto_assign |
| `metallb pool list` | List IP address pools | namespace |
| `service create loadbalancer` | Create LoadBalancer service | name, namespace, ports |

### Certificate Commands

| Command | Description | Parameters |
|---------|-------------|------------|
| `cert-manager install` | Install cert-manager | namespace, version |
| `cert-manager issuer create` | Create ClusterIssuer | name, issuer_type, server, email |
| `cert-manager certificate create` | Create Certificate | name, namespace, domains, issuer |
| `cert-manager certificate list` | List Certificates | namespace |
| `cert-manager certificate status` | Check Certificate status | name, namespace |

---

## WORKFLOWS

### Deploy a New Application

1. **Create application manifests** in `apps/{environment}/{app-name}/`
2. **Create VirtualService** for routing:
   ```yaml
   apiVersion: networking.istio.io/v1alpha3
   kind: VirtualService
   metadata:
     name: my-app-vs
     namespace: develop
   spec:
     hosts:
     - "my-app-dev.jarakube.com"
     gateways:
     - istio-ingress-internal/jarakube-com-internal-shared-gateway
     http:
     - match:
       - uri:
           prefix: /
       route:
       - destination:
           host: my-app-service
           port:
             number: 80
   ```
3. **Create ExternalSecret** for application secrets
4. **Update Flux Kustomization** to include the new application
5. **Commit and push** changes to trigger Flux sync

### Set Up New Domain

1. **Create Gateway** for the domain:
   ```yaml
   apiVersion: networking.istio.io/v1
   kind: Gateway
   metadata:
     name: my-domain-gateway
     namespace: istio-ingress-internal
   spec:
     selector:
       istio: internal-gateway
     servers:
     - port:
         number: 80
         name: http
         protocol: HTTP
       hosts:
       - "*.my-domain.com"
       tls:
         httpsRedirect: true
     - port:
         number: 443
         name: https
         protocol: HTTPS
       hosts:
       - "*.my-domain.com"
       tls:
         mode: SIMPLE
         credentialName: my-domain-wildcard-tls
   ```
2. **Create Certificate** for the domain
3. **Configure DNS** to point to MetalLB IP
4. **Create VirtualServices** for applications on the domain

### Vault Auto-Unseal Setup

1. **Create unseal key secret:**
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: vault-unseal-key
     namespace: vault
   type: Opaque
   data:
     unseal_key: <base64-encoded-unseal-key>
   ```
2. **Create CronJob for auto-unseal:**
   ```yaml
   apiVersion: batch/v1
   kind: CronJob
   metadata:
     name: vault-auto-unseal
     namespace: vault
   spec:
     schedule: "*/10 * * * *"
     jobTemplate:
       spec:
         template:
           spec:
             containers:
             - name: auto-unseal
               image: bitnami/kubectl:latest
               command: ["/bin/sh", "/scripts/auto-unseal.sh"]
               env:
               - name: UNSEAL_KEY
                 valueFrom:
                   secretKeyRef:
                     name: vault-unseal-key
                     key: unseal_key
             restartPolicy: OnFailure
   ```
3. **Create RBAC** for the CronJob service account

---

## PROJECT STRUCTURE

```
k8s-operations/
├── clusters/
│   └── jarakube/
│       ├── infrastructure.yaml
│       ├── apps-develop.yaml
│       ├── apps-production.yaml
│       └── kustomization.yaml
├── flux-system/
│   └── flux-system/
│       ├── gotk-sync.yaml
│       ├── gotk-components.yaml
│       └── kustomization.yaml
├── infrastructure/
│   ├── kustomization.yaml
│   ├── networking/
│   │   ├── istio-system/
│   │   │   ├── namespaces.yaml
│   │   │   ├── external-jarakube-eu-gateway.yaml
│   │   │   ├── internal-jarakube-com-gateway.yaml
│   │   │   ├── istio-ingress-external-deployment.yaml
│   │   │   ├── istio-ingress-internal-deployment.yaml
│   │   │   └── kustomization.yaml
│   │   └── metallb-config/
│   │       ├── ingress-metallb-config.yaml
│   │       └── ...
│   ├── security/
│   │   ├── cert-manager/
│   │   ├── external-secret/
│   │   │   ├── secret-stores/
│   │   │   │   └── secret-store.yaml
│   │   │   └── all-external-secrets/
│   │   │       ├── develop/
│   │   │       │   ├── jarapi-secret.yaml
│   │   │       │   └── ...
│   │   │       └── infrastructure/
│   │   └── vault/
│   │       ├── namespace.yaml
│   │       ├── vault-values.yaml
│   │       ├── vault-virtual-service.yaml
│   │       ├── vault-cert.yaml
│   │       ├── auto-unseal-shamir/
│   │       │   ├── cronjob.yaml
│   │       │   ├── rbac.yaml
│   │       │   ├── script-configmap.yaml
│   │       │   └── kustomization.yaml
│   │       └── kustomization.yaml
│   ├── sources/
│   │   ├── helmrepo-istio.yaml
│   │   ├── helmrepo-bitnami.yaml
│   │   └── ...
│   ├── storage/
│   ├── observability/
│   ├── platform/
│   └── automation/
└── apps/
    ├── develop/
    │   ├── jaraco-trading-be/
    │   │   ├── jaraco-trading-be-virtual-service.yaml
    │   │   ├── jaraco-trading-be-deployment.yaml
    │   │   └── kustomization.yaml
    │   └── ...
    └── production/
        └── ...
```

---

## DOMAINS AND NETWORKING

### Domains
- `*.jarakube.com` - Primary domain for internal services
- `*.jarakube.eu` - Primary domain for external services

### Gateways
- **External Gateway** (`istio-ingress-external` namespace): Handles external traffic on `*.jarakube.eu`
- **Internal Gateway** (`istio-ingress-internal` namespace): Handles internal traffic on `*.jarakube.com`
- **Egress Gateway** (`istio-egress` namespace): Handles outbound traffic

### IP Addresses
- External IP: `217.154.156.240` (external-apollo node)
- MetalLB Ingress Pool: `192.168.178.121/32`

---

## BEST PRACTICES

### Flux CD
1. **Use Kustomize** for application manifests
2. **Separate environments** (develop, production) with different Kustomization resources
3. **Use HelmRepository** for Helm charts
4. **Enable prune** to automatically remove resources not in Git
5. **Set appropriate sync intervals** (1m for sources, 10m for kustomizations)

### Istio
1. **Use separate Gateways** for different domains
2. **Configure HTTPS redirection** for all HTTP traffic
3. **Use SIMPLE TLS mode** for wildcard certificates
4. **Label Gateways** with `istio: external-gateway` or `istio: internal-gateway`
5. **Use prefix matching** in VirtualServices for flexible routing

### Vault
1. **Enable HA mode** with Raft storage for production
2. **Configure auto-unseal** to prevent manual intervention
3. **Use OIDC authentication** with Keycloak for secure access
4. **Store secrets in KV v2** engine
5. **Rotate unseal keys** regularly
6. **Use separate paths** for different environments (dev, prod)

### External Secrets
1. **Use ClusterSecretStore** for shared Vault backend
2. **Create namespace-specific ExternalSecrets** for applications
3. **Set refresh intervals** based on secret sensitivity
4. **Use property references** to map Vault keys to Kubernetes secret keys
5. **Validate secret access** before deploying applications

### Security
1. **Use TLS for all external traffic**
2. **Configure network policies** for pod communication
3. **Use RBAC** for service accounts
4. **Rotate certificates** regularly
5. **Audit Vault access** logs regularly

---

## TROUBLESHOOTING

### Flux CD Issues

**Problem:** Flux not syncing changes
- Check Flux logs: `kubectl logs -n flux-system deploy/flux-controller`
- Check reconciliation status: `flux get kustomizations -n flux-system`
- Check GitRepository status: `flux get sources git -n flux-system`
- Verify SSH key or token has access to repository

**Problem:** Kustomization reconciliation failed
- Check Kustomization status: `flux get kustomizations -n <namespace>`
- Check for YAML syntax errors in manifests
- Verify all referenced resources exist
- Check for missing dependencies

### Istio Issues

**Problem:** VirtualService not routing traffic
- Check VirtualService exists: `kubectl get virtualservices -n <namespace>`
- Check Gateway exists: `kubectl get gateways -n <gateway-namespace>`
- Check Istio logs: `kubectl logs -n istio-system deploy/istiod`
- Verify hostnames match Gateway configuration
- Check for TLS configuration issues

**Problem:** 503 Service Unavailable
- Check DestinationRule exists for service
- Verify service is running: `kubectl get pods -n <namespace>`
- Check service endpoints: `kubectl get endpoints -n <namespace>`
- Verify port numbers match between VirtualService and Service

### Vault Issues

**Problem:** Vault pod not starting
- Check Vault logs: `kubectl logs -n vault deploy/vault`
- Check if Vault is sealed: `kubectl exec -n vault deploy/vault -c vault -- vault status`
- Verify unseal keys are correct
- Check storage PVC is bound

**Problem:** Cannot access Vault UI
- Verify VirtualService is configured correctly
- Check Vault service is running: `kubectl get svc -n vault`
- Verify TLS configuration if using HTTPS
- Check network policies allow access

**Problem:** External Secrets not syncing
- Check ExternalSecret status: `kubectl get externalsecrets -n <namespace>`
- Check ClusterSecretStore exists: `kubectl get clustersecretstores`
- Verify Vault token has access to secret path
- Check Vault token secret exists: `kubectl get secret -n vault vault-token`
- Check ExternalSecret refresh interval

---

## COMMON TASKS

### Add New Application

1. Create application directory:
   ```bash
   mkdir -p apps/develop/my-app
   ```

2. Create deployment manifest (`apps/develop/my-app/my-app-deployment.yaml`):
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: my-app
     namespace: develop
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: my-app
     template:
       metadata:
         labels:
           app: my-app
       spec:
         containers:
         - name: my-app
           image: my-app:latest
           ports:
           - containerPort: 8080
           envFrom:
           - secretRef:
               name: my-app-secret
   ```

3. Create service manifest (`apps/develop/my-app/my-app-service.yaml`):
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: my-app-service
     namespace: develop
   spec:
     selector:
       app: my-app
     ports:
     - port: 80
       targetPort: 8080
   ```

4. Create VirtualService manifest (`apps/develop/my-app/my-app-virtual-service.yaml`):
   ```yaml
   apiVersion: networking.istio.io/v1alpha3
   kind: VirtualService
   metadata:
     name: my-app-vs
     namespace: develop
   spec:
     hosts:
     - "my-app-dev.jarakube.com"
     gateways:
     - istio-ingress-internal/jarakube-com-internal-shared-gateway
     http:
     - match:
       - uri:
           prefix: /
       route:
       - destination:
           host: my-app-service
           port:
             number: 80
   ```

5. Create ExternalSecret manifest (`infrastructure/security/external-secret/all-external-secrets/develop/my-app-secret.yaml`):
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: my-app-secret
     namespace: develop
   spec:
     refreshInterval: "60m"
     secretStoreRef:
       name: vault-backend
       kind: ClusterSecretStore
     target:
       name: my-app-secret
     data:
     - secretKey: db-password
       remoteRef:
         key: "dev"
         property: "my-app-db-password"
   ```

6. Create kustomization.yaml (`apps/develop/my-app/kustomization.yaml`):
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - my-app-deployment.yaml
     - my-app-service.yaml
     - my-app-virtual-service.yaml
   ```

7. Update develop kustomization (`apps/develop/kustomization.yaml`):
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - my-app/
     # ... other apps
   ```

8. Commit and push changes

### Update Application Image

1. Update image in deployment manifest
2. Commit and push changes
3. Flux will automatically sync changes within the reconciliation interval
4. Or force sync: `flux reconcile kustomization my-app -n develop`

### Configure New Domain

1. Create Gateway manifest (`infrastructure/networking/istio-system/my-domain-gateway.yaml`):
   ```yaml
   apiVersion: networking.istio.io/v1
   kind: Gateway
   metadata:
     name: my-domain-gateway
     namespace: istio-ingress-internal
   spec:
     selector:
       istio: internal-gateway
     servers:
     - port:
         number: 80
         name: http
         protocol: HTTP
       hosts:
       - "*.my-domain.com"
       tls:
         httpsRedirect: true
     - port:
         number: 443
         name: https
         protocol: HTTPS
       hosts:
       - "*.my-domain.com"
       tls:
         mode: SIMPLE
         credentialName: my-domain-wildcard-tls
   ```

2. Create Certificate manifest (`infrastructure/networking/istio-system/my-domain-certificate.yaml`):
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: Certificate
   metadata:
     name: my-domain-wildcard-tls
     namespace: istio-ingress-internal
   spec:
     secretName: my-domain-wildcard-tls
     issuerRef:
       name: letsencrypt-prod
       kind: ClusterIssuer
     dnsNames:
     - "*.my-domain.com"
     - "my-domain.com"
   ```

3. Update Istio kustomization to include new Gateway
4. Configure DNS to point to MetalLB IP
5. Commit and push changes

---

## RESOURCES

### Official Documentation
- [Flux CD Documentation](https://fluxcd.io/flux/docs/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Vault Documentation](https://www.vaultproject.io/docs)
- [External Secrets Documentation](https://external-secrets.io/docs/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [MetalLB Documentation](https://metallb.universe.tf/docs/)

### Helm Charts
- [Istio Helm Charts](https://istio-release.storage.googleapis.com/charts)
- [Vault Helm Chart](https://github.com/hashicorp/vault-helm)
- [cert-manager Helm Chart](https://github.com/cert-manager/cert-manager)
- [External Secrets Helm Chart](https://github.com/external-secrets/external-secrets)

### Useful Commands

**Check all resources:**
```bash
kubectl get all -A
```

**Check Istio resources:**
```bash
kubectl get gateways,virtualservices,destinationrules -A
```

**Check Flux status:**
```bash
flux get all -A
```

**Check Vault status:**
```bash
kubectl exec -n vault deploy/vault -c vault -- vault status
```

**Check External Secrets:**
```bash
kubectl get externalsecrets,clustersecretstores -A
```

**Check Certificates:**
```bash
kubectl get certificates,clusterissuers -A
```

---

## LIMITATIONS

1. This skill is specific to the jaraco k8s-operations project structure
2. Requires existing Kubernetes cluster with appropriate permissions
3. Assumes Istio, Vault, Flux CD, and other components are already installed
4. Some operations may require manual intervention for security-sensitive tasks
5. Always verify changes before applying to production

---

## SAFETY GUIDELINES

1. **Always backup** important data before making changes
2. **Test in develop** namespace before deploying to production
3. **Verify TLS certificates** are valid and not expired
4. **Rotate secrets** regularly, especially Vault tokens and unseal keys
5. **Monitor logs** after making changes to ensure everything is working
6. **Use git** for all changes to enable rollback
7. **Review changes** with team members before applying to production
8. **Never commit secrets** to Git (use External Secrets or Vault)

---

## NVIDIA GPU OPERATOR UPGRADE RECIPE

How to upgrade the GPU Operator (chart + driver) via GitOps. Current state
(2026-11-14): HelmRelease `gpu-operator` in `flux-system` (release
`gpu-operator-1741365764`, targetNS `gpu-operator`), chart
`gpu-operator` from HelmRepository `nvidia`
(`https://helm.ngc.nvidia.com/nvidia`) at **v26.7.1**, driver
`nvcr.io/nvidia/driver:595.91.07-ubuntu22.04` (compiled on-node,
`usePrecompiled: false`), driver-manager v0.12.1, toolkit v1.20.1,
device-plugin/GFD v0.20.1, mig-manager v0.15.1, NFD v0.19.0. Manifest:
`infrastructure/platform/gpu-operator/gpu-operator-helmrelease.yaml`
(wired via `infrastructure/platform/kustomization.yaml`).

Driver DaemonSet uses `updateStrategy: OnDelete` and nodeSelector
`nvidia.com/gpu.deploy.driver=true`; the driver upgrade controller is
enabled by default (`driver.upgradePolicy.autoUpgrade: true`,
`maxParallelUpgrades: 1`, `maxUnavailable: 25%`, GPU-pod deletion on,
drain off).

### Step 1 - bump the chart (no driver change)

1. Edit `infrastructure/platform/gpu-operator/gpu-operator-helmrelease.yaml`:
   `chart.spec.version: v26.7.1` -> latest same-major release (e.g.
   `v26.7.2`; check `https://helm.ngc.nvidia.com/nvidia/index.yaml`).
   Keep `values` unchanged so the driver version stays put - v26.7.0+
   restarts driver pods in place on cosmetic-only changes instead of
   draining nodes.
2. CRDs: `install/upgrade.crds: CreateReplace` in the HelmRelease applies
   the new chart's CRDs; the chart's pre-upgrade CRD hook
   (`operator.upgradeCRD: true`, default since v24.9) is the fallback.
3. Commit with `--signoff`, push via PR, then:
   ```bash
   flux reconcile helmrelease gpu-operator -n flux-system
   flux get helmrelease gpu-operator -n flux-system
   kubectl get pods -n gpu-operator
   ```

### Step 2 - bump the driver (separate commit/PR)

Add to `values` in the same HelmRelease (maps to ClusterPolicy
`spec.driver.*`):

```yaml
values:
  driver:
    version: "615.71.10"   # recommended for v26.7.2; alternatives 595.112.07, 610.57.04
```

Pre-checks before committing step 2:

- Scan the candidate driver image and confirm the kernel CVEs are fixed:
  `trivy image nvcr.io/nvidia/driver:<ver>-ubuntu22.04 --severity CRITICAL`
  - the 2026-11-14 scan showed 25 CRITICAL kernel CVEs in
    `linux-libc-dev 5.15.0-187.197`; require `>= 5.15.0-203.213`.
- Image tag suffix must match node OS (verify via NFD label
  `feature.node.kubernetes.io/system-os_release.ID`).
- containerd >= 2.0 required since GPU Operator v26.7.0:
  `kubectl debug node/<gpu-node> -it --image=busybox -- chroot /host containerd --version`
- Cluster runs k8s 1.30.10; NVIDIA's validated matrix for v26.7.x is
  1.33-1.37 - treat as unvalidated and watch operator logs.
- Known issue on H100: upgrading 595.91.07 -> 615.x without a node reboot
  can break later MIG reconfiguration (Xid 119); reboot the node after
  the driver upgrade or run `nvidia-smi -r` in the driver pod before
  changing MIG config.
- Keep the existing `toolkit.env` CONTAINERD_* values in `values`.

Monitor the rollout (upgrade controller state machine per node):

```bash
kubectl get node -l nvidia.com/gpu.present \
  -ojsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.nvidia\.com/gpu-driver-upgrade-state}{"\n"}{end}'
# upgrade-required -> cordon-required -> pod-deletion-required ->
# pod-restart-required -> validation-required -> uncordon-required -> upgrade-done
kubectl get events -A --sort-by=.lastTimestamp | grep GPUDriverUpgrade
kubectl logs -n gpu-operator deploy/gpu-operator-<hash> | grep -i upgrade
# Prometheus: gpu_operator_nodes_upgrades_{in_progress,done,failed}
kubectl exec -n gpu-operator <driver-pod> -c nvidia-driver-ctr -- nvidia-smi -L
```

Recovery: node stuck in `upgrade-failed` -> fix cause, then
`kubectl label node <node> nvidia.com/gpu-driver-upgrade-state=upgrade-required --overwrite`;
skip a node with `nvidia.com/gpu-driver-upgrade.skip=true`; pause with
`driver.upgradePolicy.autoUpgrade: false` in values.

### Step 3 - verify + rescan

```bash
kubectl get clusterpolicy cluster-policy -o jsonpath='{.status.state}'  # Ready
kubectl get pods -n gpu-operator -l app=nvidia-driver-daemonset
kubectl get pods -n gpu-operator -l app=nvidia-device-plugin-daemonset
# Trivy rescans on image change; confirm the driver report drops the kernel CRITICALs
kubectl get vulnerabilityreports -n gpu-operator
```

Notes: mig-manager stays v0.15.1 in v26.7.2 - if CVE-2025-23266
(mig-parted -> 0.12.2) persists after the rescan it needs a newer
mig-manager. Rollback = revert the commit; Flux reconciles back. Never
patch the ClusterPolicy directly with kubectl - Git is the source of
truth. If Pod Security Admission applies, label the namespace
`pod-security.kubernetes.io/enforce=privileged`.

---

## VERSION HISTORY

- **1.1.0** (2026-11-14): Added "NVIDIA GPU Operator upgrade recipe" -
  GitOps procedure to bump the gpu-operator HelmRelease chart and driver
  version, upgrade-controller monitoring, and pre-checks.
- **1.0.0** (2026-05-16): Initial version - Comprehensive Kubernetes operations skill for jaraco project
