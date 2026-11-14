# Kubernetes Operations Quick Start Guide

## 🚀 Getting Started

This guide helps you quickly perform common tasks in the k8s-operations project.

---

## 📋 Common Commands Cheat Sheet

### Flux CD
```bash
# Check Flux status
flux get all -A

# Force sync a specific kustomization
flux reconcile kustomization <name> -n <namespace>

# Check Flux logs
kubectl logs -n flux-system deploy/flux-controller -f

# List all Flux sources
flux get sources git,helm -A

# Suspend Flux reconciliation
flux suspend kustomization <name> -n <namespace>

# Resume Flux reconciliation
flux resume kustomization <name> -n <namespace>
```

### Istio
```bash
# List all Gateways
kubectl get gateways -A

# List all VirtualServices
kubectl get virtualservices -A

# Check Istio logs
kubectl logs -n istio-system deploy/istiod -f

# Analyze Istio configuration
istioctl analyze -A

# Check Istio version
istioctl version

# Get Istio status
istioctl proxy-status
```

### Vault
```bash
# Check Vault status
kubectl exec -n vault deploy/vault -c vault -- vault status

# Check Vault logs
kubectl logs -n vault deploy/vault -c vault -f

# Login to Vault
kubectl exec -it -n vault deploy/vault -c vault -- vault login

# List secrets
kubectl exec -n vault deploy/vault -c vault -- vault kv list kv/jaraco

# Read a secret
kubectl exec -n vault deploy/vault -c vault -- vault kv get kv/jaraco/dev

# Check auto-unseal CronJob
kubectl get cronjobs -n vault
kubectl logs -n vault job/vault-auto-unseal-<id> -f
```

### External Secrets
```bash
# List all ExternalSecrets
kubectl get externalsecrets -A

# List ClusterSecretStores
kubectl get clustersecretstores

# Check ExternalSecret status
kubectl describe externalsecret <name> -n <namespace>

# Check ExternalSecret logs
kubectl logs -n external-secrets deploy/external-secrets -f
```

### Networking
```bash
# Check MetalLB configuration
kubectl get ipaddresspools,l2advertisements -n metallb-system

# Check LoadBalancer services
kubectl get svc -A | grep LoadBalancer

# Check service endpoints
kubectl get endpoints -A

# Check DNS configuration
kubectl get cm -n kube-system coredns -o yaml
```

### Certificates
```bash
# List all Certificates
kubectl get certificates -A

# List ClusterIssuers
kubectl get clusterissuers

# Check Certificate status
kubectl describe certificate <name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager -f
```

---

## 🎯 Quick Tasks

### 1. Deploy a New Application

```bash
# Create application directory
mkdir -p apps/develop/my-new-app

# Create deployment.yaml
cat > apps/develop/my-new-app/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-new-app
  namespace: develop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-new-app
  template:
    metadata:
      labels:
        app: my-new-app
    spec:
      containers:
      - name: my-new-app
        image: my-registry/my-new-app:latest
        ports:
        - containerPort: 8080
        envFrom:
        - secretRef:
            name: my-new-app-secret
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        securityContext:
          runAsNonRoot: true
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
EOF

# Create service.yaml
cat > apps/develop/my-new-app/service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: my-new-app-service
  namespace: develop
spec:
  selector:
    app: my-new-app
  ports:
  - port: 80
    targetPort: 8080
EOF

# Create virtual-service.yaml
cat > apps/develop/my-new-app/virtual-service.yaml <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-new-app-vs
  namespace: develop
spec:
  hosts:
  - "my-new-app-dev.jarakube.com"
  gateways:
  - istio-ingress-internal/jarakube-com-internal-shared-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: my-new-app-service
        port:
          number: 80
EOF

# Create kustomization.yaml
cat > apps/develop/my-new-app/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - virtual-service.yaml
EOF

# Update develop kustomization
# Edit apps/develop/kustomization.yaml and add:
#   - my-new-app/

# Create ExternalSecret
cat > infrastructure/security/external-secret/all-external-secrets/develop/my-new-app-secret.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-new-app-secret
  namespace: develop
spec:
  refreshInterval: "60m"
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: my-new-app-secret
  data:
  - secretKey: db-password
    remoteRef:
      key: "dev"
      property: "my-new-app-db-password"
  - secretKey: db-url
    remoteRef:
      key: "dev"
      property: "my-new-app-db-url"
EOF

# Commit and push changes
git add .
git commit -m "Add my-new-app deployment"
git push
```

### 2. Update Application Image

```bash
# Edit the deployment.yaml and update the image
# Change: image: my-registry/my-new-app:latest
# To:     image: my-registry/my-new-app:v1.0.1

# Commit and push
git add apps/develop/my-new-app/deployment.yaml
git commit -m "Update my-new-app to v1.0.1"
git push

# Or force immediate sync
flux reconcile kustomization my-new-app -n develop
```

### 3. Add New Domain

```bash
# Create Gateway for new domain
cat > infrastructure/networking/istio-system/my-new-domain-gateway.yaml <<EOF
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: my-new-domain-gateway
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
    - "*.my-new-domain.com"
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "*.my-new-domain.com"
    tls:
      mode: SIMPLE
      credentialName: my-new-domain-wildcard-tls
EOF

# Create Certificate
cat > infrastructure/networking/istio-system/my-new-domain-certificate.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-new-domain-wildcard-tls
  namespace: istio-ingress-internal
spec:
  secretName: my-new-domain-wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "*.my-new-domain.com"
  - "my-new-domain.com"
EOF

# Update Istio kustomization
# Edit infrastructure/networking/istio-system/kustomization.yaml and add:
#   - my-new-domain-gateway.yaml
#   - my-new-domain-certificate.yaml

# Configure DNS (external step)
# Add A record for *.my-new-domain.com pointing to 192.168.178.121

# Commit and push
git add .
git commit -m "Add my-new-domain.com gateway and certificate"
git push
```

### 4. Create New External Secret

```bash
# Create ExternalSecret manifest
cat > infrastructure/security/external-secret/all-external-secrets/develop/my-existing-app-new-secret.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-existing-app-new-secret
  namespace: develop
spec:
  refreshInterval: "30m"
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: my-existing-app-new-secret
  data:
  - secretKey: api-key
    remoteRef:
      key: "dev"
      property: "my-existing-app-api-key"
  - secretKey: api-url
    remoteRef:
      key: "dev"
      property: "my-existing-app-api-url"
EOF

# Update the application deployment to use the new secret
# Edit apps/develop/my-existing-app/deployment.yaml and add:
#   envFrom:
#   - secretRef:
#       name: my-existing-app-new-secret

# Commit and push
git add .
git commit -m "Add new secret for my-existing-app"
git push
```

### 5. Troubleshoot Application

```bash
# Check application pods
kubectl get pods -n develop -l app=my-app

# Check pod logs
kubectl logs -n develop deploy/my-app -f

# Check pod events
kubectl describe pod -n develop <pod-name>

# Check service
kubectl get svc -n develop my-app-service
kubectl describe svc -n develop my-app-service

# Check endpoints
kubectl get endpoints -n develop my-app-service
kubectl describe endpoints -n develop my-app-service

# Check VirtualService
kubectl get virtualservice -n develop my-app-vs -o yaml
kubectl describe virtualservice -n develop my-app-vs

# Check Istio proxy logs
kubectl logs -n develop <pod-name> -c istio-proxy -f

# Test connectivity from within cluster
kubectl run -it --rm --restart=Never test-pod --image=busybox -n develop -- sh
# Inside the pod:
wget -O- http://my-app-service:80
curl -v http://my-app-service:80

# Test from outside cluster
curl -v https://my-app-dev.jarakube.com
```

### 6. Vault Operations

```bash
# Check Vault status
kubectl exec -n vault deploy/vault -c vault -- vault status

# If Vault is sealed, unseal it
kubectl exec -it -n vault deploy/vault -c vault -- vault operator unseal <unseal-key>

# Login to Vault
VAULT_TOKEN=$(kubectl get secret -n vault vault-token -o jsonpath='{.data.token}' | base64 -d)
kubectl exec -it -n vault deploy/vault -c vault -- vault login $VAULT_TOKEN

# Add new secret
kubectl exec -n vault deploy/vault -c vault -- vault kv put kv/jaraco/dev my-new-secret-key=my-secret-value

# Update existing secret
kubectl exec -n vault deploy/vault -c vault -- vault kv put kv/jaraco/dev my-existing-key=new-value

# List all secrets in a path
kubectl exec -n vault deploy/vault -c vault -- vault kv list kv/jaraco/dev

# Read a secret
kubectl exec -n vault deploy/vault -c vault -- vault kv get kv/jaraco/dev
```

### 7. Flux Troubleshooting

```bash
# Check Flux sync status
flux get kustomizations -A

# Check GitRepository status
flux get sources git -A

# Check HelmRepository status
flux get sources helm -A

# Check Flux reconciliation logs
kubectl logs -n flux-system deploy/flux-controller -f

# Check Flux events
kubectl get events -n flux-system --sort-by='.metadata.creationTimestamp'

# Force reconcile all Flux resources
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization flux-system -n flux-system

# Check what Flux would apply (dry run)
flux build kustomization my-app -n develop --path ./apps/develop/my-app
```

---

## 🔍 Debugging Guide

### Problem: Application not accessible via domain

**Checklist:**
1. ✅ VirtualService exists: `kubectl get virtualservice -n <namespace>`
2. ✅ Gateway exists: `kubectl get gateway -n <gateway-namespace>`
3. ✅ Hostname matches: Check VirtualService hosts match the domain you're accessing
4. ✅ Gateway selector matches: Check Gateway selector matches VirtualService gateway
5. ✅ Service exists: `kubectl get svc -n <namespace>`
6. ✅ Endpoints exist: `kubectl get endpoints -n <namespace>`
7. ✅ Pods are running: `kubectl get pods -n <namespace>`
8. ✅ DNS is configured: Check DNS record points to correct IP
9. ✅ TLS certificate is valid (for HTTPS)

**Debug commands:**
```bash
# Check Istio configuration
istioctl analyze -A

# Check Istio proxy config
istioctl proxy-config routes -n <namespace> <pod-name>

# Check service mesh membership
istioctl proxy-status

# Test connectivity from Istio ingress
kubectl exec -it -n istio-ingress-internal deploy/<ingress-gateway> -c istio-proxy -- curl -v http://<service-name>.<namespace>.svc.cluster.local:80
```

### Problem: ExternalSecret not syncing

**Checklist:**
1. ✅ ExternalSecret exists: `kubectl get externalsecret -n <namespace>`
2. ✅ ClusterSecretStore exists: `kubectl get clustersecretstore vault-backend`
3. ✅ Vault token secret exists: `kubectl get secret -n vault vault-token`
4. ✅ Vault is accessible: `kubectl exec -n vault deploy/vault -c vault -- vault status`
5. ✅ Secret exists in Vault: `kubectl exec -n vault deploy/vault -c vault -- vault kv get <path>`
6. ✅ External Secrets operator is running: `kubectl get pods -n external-secrets`

**Debug commands:**
```bash
# Check ExternalSecret status
kubectl describe externalsecret <name> -n <namespace>

# Check External Secrets operator logs
kubectl logs -n external-secrets deploy/external-secrets -f

# Check ClusterSecretStore
kubectl get clustersecretstore vault-backend -o yaml

# Test Vault connection manually
VAULT_TOKEN=$(kubectl get secret -n vault vault-token -o jsonpath='{.data.token}' | base64 -d)
curl -H "X-Vault-Token: $VAULT_TOKEN" http://vault.vault.svc.cluster.local:8200/v1/kv/jaraco/data/dev | jq
```

### Problem: Flux not syncing changes

**Checklist:**
1. ✅ Changes are committed and pushed to the correct branch
2. ✅ GitRepository is healthy: `flux get sources git -n flux-system`
3. ✅ Kustomization is healthy: `flux get kustomizations -n <namespace>`
4. ✅ Flux controller is running: `kubectl get pods -n flux-system`
5. ✅ SSH key or token has access to the repository
6. ✅ Path in Kustomization matches the directory structure

**Debug commands:**
```bash
# Check Flux reconciliation status
flux get kustomization <name> -n <namespace>

# Check GitRepository status
flux get source git flux-system -n flux-system

# Check Flux logs
kubectl logs -n flux-system deploy/flux-controller -f

# Check Flux events
kubectl get events -n flux-system --sort-by='.metadata.creationTimestamp'

# Force reconcile
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization <name> -n <namespace>

# Check what Flux sees in Git
flux build kustomization <name> -n <namespace> --path <path>
```

---

## 📊 Monitoring Commands

### Cluster Health
```bash
# Check all nodes
kubectl get nodes -o wide

# Check node conditions
kubectl describe node <node-name>

# Check cluster capacity
kubectl top nodes

# Check pod resource usage
kubectl top pods -A
```

### Istio Metrics
```bash
# Check Istio service metrics
kubectl get svc -n istio-system istio-telemetry

# Check Prometheus (if installed)
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Then open http://localhost:9090

# Check Grafana (if installed)
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Then open http://localhost:3000
```

### Vault Monitoring
```bash
# Check Vault storage
kubectl get pvc -n vault

# Check Vault memory usage
kubectl top pods -n vault

# Check Vault audit logs (if enabled)
kubectl logs -n vault deploy/vault -c vault | grep AUDIT
```

---

## 🎯 Best Practices

### 1. Always Test in Develop First
- Deploy to `develop` namespace first
- Test thoroughly before promoting to `production`
- Use the same configuration patterns across environments

### 2. Use Git for Everything
- All changes should go through Git
- Use meaningful commit messages
- Review changes before merging

### 3. Security First
- Never commit secrets to Git
- Use External Secrets for all sensitive data
- Enable TLS for all external traffic
- Use network policies to restrict pod communication

### 4. Monitor After Changes
- Check logs after deploying changes
- Monitor resource usage
- Verify health checks are passing
- Check Istio metrics for traffic issues

### 5. Document Changes
- Update README files when adding new components
- Document configuration requirements
- Note any manual steps required

---

## 📞 Getting Help

### Common Issues and Solutions

**Issue: 503 Service Unavailable**
- Solution: Check if the service has endpoints and pods are running

**Issue: 404 Not Found**
- Solution: Check VirtualService hostnames and paths match the request

**Issue: Connection Refused**
- Solution: Check if the pod is listening on the correct port

**Issue: TLS Certificate Errors**
- Solution: Check Certificate status and ensure DNS is configured correctly

**Issue: Vault Sealed**
- Solution: Use the auto-unseal CronJob or manually unseal with unseal keys

### Where to Look for More Information

1. **Flux CD Docs**: https://fluxcd.io/flux/docs/
2. **Istio Docs**: https://istio.io/latest/docs/
3. **Vault Docs**: https://www.vaultproject.io/docs
4. **External Secrets Docs**: https://external-secrets.io/docs/
5. **Project Documentation**: Check the Notion page linked in README.md

---

## 🚨 Emergency Procedures

### Vault is Sealed and Auto-Unseal Not Working

```bash
# Manual unseal
kubectl exec -it -n vault deploy/vault -c vault -- vault operator unseal <unseal-key-1>
kubectl exec -it -n vault deploy/vault -c vault -- vault operator unseal <unseal-key-2>
kubectl exec -it -n vault deploy/vault -c vault -- vault operator unseal <unseal-key-3>

# Check auto-unseal CronJob
kubectl get cronjobs -n vault
kubectl describe cronjob -n vault vault-auto-unseal

# Manual trigger of auto-unseal job
kubectl create job --from=cronjob/vault-auto-unseal -n vault manual-vault-unseal
```

### Flux Not Working

```bash
# Restart Flux controller
kubectl rollout restart -n flux-system deploy/flux-controller

# Check Flux installation
flux check --pre

# Reinstall Flux (last resort)
flux uninstall -n flux-system --keep-namespace
flux bootstrap github --owner=jaracogmbh --repository=k8s-operations --branch=main --path=./clusters/jarakube
```

### Istio Issues

```bash
# Restart Istio control plane
kubectl rollout restart -n istio-system deploy/istiod

# Restart Istio ingress gateways
kubectl rollout restart -n istio-ingress-external deploy/external-ingressgateway
kubectl rollout restart -n istio-ingress-internal deploy/internal-ingressgateway

# Check Istio installation
istioctl verify-install -f <installation-yaml>
```

---

## 📝 Templates

### VirtualService Template

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: {{APP_NAME}}-vs
  namespace: {{NAMESPACE}}
spec:
  hosts:
  - "{{APP_NAME}}-{{ENV}}.jarakube.com"
  gateways:
  - istio-ingress-internal/jarakube-com-internal-shared-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: {{APP_NAME}}-service
        port:
          number: 80
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 2s
```

### ExternalSecret Template

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{APP_NAME}}-secret
  namespace: {{NAMESPACE}}
spec:
  refreshInterval: "60m"
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: {{APP_NAME}}-secret
  data:
  - secretKey: {{SECRET_KEY}}
    remoteRef:
      key: "{{ENV}}"
      property: "{{VAULT_PROPERTY}}"
```

### Deployment Template

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{APP_NAME}}
  namespace: {{NAMESPACE}}
spec:
  replicas: 1
  revisionHistoryLimit: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
  selector:
    matchLabels:
      app: {{APP_NAME}}
  template:
    metadata:
      labels:
        app: {{APP_NAME}}
    spec:
      securityContext:
        runAsNonRoot: true
        fsGroup: 1000
      containers:
      - name: {{APP_NAME}}
        image: {{IMAGE}}:{{TAG}}
        ports:
        - containerPort: {{PORT}}
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        securityContext:
          runAsNonRoot: true
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        envFrom:
        - secretRef:
            name: {{APP_NAME}}-secret
```

---

## 🎉 Success Checklist

After completing any task, verify:

- [ ] Changes are committed and pushed to Git
- [ ] Flux has synced the changes (check with `flux get kustomizations`)
- [ ] Pods are running (check with `kubectl get pods -n <namespace>`)
- [ ] Services are accessible (test with curl or browser)
- [ ] Logs show no errors (check with `kubectl logs -n <namespace> <pod>`)
- [ ] Monitoring shows healthy status
- [ ] Team members are notified of changes
