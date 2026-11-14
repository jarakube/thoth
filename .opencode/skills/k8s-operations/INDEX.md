# Kubernetes Operations Skill Index

## 📚 Documentation Overview

This skill provides comprehensive support for the **jaraco k8s-operations** project, covering all aspects of Kubernetes infrastructure management including Flux CD, Istio service mesh, Vault secrets management, and more.

---

## 🎯 Quick Navigation

| Section | Description | Files |
|---------|-------------|-------|
| **Main Documentation** | Skill overview, capabilities, and usage | [SKILL.md](./SKILL.md) |
| **Quick Start** | Hands-on guide with common tasks | [QUICKSTART.md](./QUICKSTART.md) |
| **Configuration** | Skill-specific settings | [config.yaml](./config.yaml) |
| **Examples** | Practical YAML examples | [examples/](./examples/) |

---

## 📋 Skill Capabilities

### 🔄 Flux CD Management
- **GitOps Automation**: Automated deployments from Git repositories
- **Multi-Environment**: Support for develop and production environments
- **Helm Integration**: Helm chart deployment and management
- **Health Checks**: Automatic verification of deployed resources
- **Image Automation**: Automatic container image updates

**Files:**
- [Flux Examples](./examples/flux-example.yaml)

**Common Tasks:**
- Deploy new applications
- Update application images
- Troubleshoot sync issues
- Configure Helm repositories
- Set up image automation

---

### 🌐 Istio Service Mesh
- **Gateways**: External and internal traffic management
- **VirtualServices**: Advanced routing and traffic control
- **TLS Termination**: HTTPS and mTLS configuration
- **Traffic Management**: Canary deployments, A/B testing
- **Observability**: Metrics, logs, and traces

**Files:**
- [Gateway Examples](./examples/gateway-example.yaml)
- [VirtualService Examples](./examples/virtualservice-example.yaml)

**Common Tasks:**
- Create new Gateways for domains
- Configure VirtualServices for applications
- Set up HTTPS redirection
- Implement traffic routing rules
- Troubleshoot connectivity issues

---

### 🔐 Vault Integration
- **HA Deployment**: High-availability Vault with Raft storage
- **Auto-Unseal**: Automatic unsealing with CronJobs
- **OIDC Authentication**: Keycloak integration for secure access
- **Secrets Management**: KV v2 secrets engine
- **PKI**: Certificate authority for internal certificates

**Files:**
- [Vault Examples](./examples/vault-example.yaml)

**Common Tasks:**
- Deploy and configure Vault
- Set up auto-unseal mechanism
- Configure OIDC with Keycloak
- Create and manage secrets
- Set up certificate authority

---

### 🔑 External Secrets
- **Vault Backend**: Sync secrets from Vault to Kubernetes
- **ClusterSecretStore**: Centralized secret store configuration
- **ExternalSecret Resources**: Application-specific secret synchronization
- **Refresh Intervals**: Automatic secret rotation

**Files:**
- [ExternalSecret Examples](./examples/external-secret-example.yaml)

**Common Tasks:**
- Create ExternalSecrets for applications
- Configure ClusterSecretStore
- Set up secret refresh schedules
- Troubleshoot secret sync issues

---

### 🌍 Networking
- **MetalLB**: Load balancing for bare metal clusters
- **IP Address Pools**: Management of external IPs
- **DNS Configuration**: Domain management
- **Service Mesh**: Istio integration

**Common Tasks:**
- Configure MetalLB IP pools
- Set up LoadBalancer services
- Manage DNS records
- Configure network policies

---

### 🔒 Certificate Management
- **cert-manager**: Automatic TLS certificate provisioning
- **ClusterIssuers**: Let's Encrypt integration
- **Wildcard Certificates**: Support for wildcard domains
- **Certificate Rotation**: Automatic renewal

**Common Tasks:**
- Create wildcard certificates
- Configure ClusterIssuers
- Set up automatic renewal
- Troubleshoot certificate issues

---

## 📁 Project Structure

```
k8s-operations/
├── .opencode/
│   └── skills/
│       └── k8s-operations/
│           ├── SKILL.md              # Main skill documentation
│           ├── QUICKSTART.md         # Quick start guide
│           ├── config.yaml           # Skill configuration
│           ├── INDEX.md              # This file
│           └── examples/             # Example YAML files
│               ├── virtualservice-example.yaml
│               ├── gateway-example.yaml
│               ├── flux-example.yaml
│               ├── vault-example.yaml
│               └── external-secret-example.yaml
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
│   │   └── istio-system/
│   │       ├── namespaces.yaml
│   │       ├── external-jarakube-eu-gateway.yaml
│   │       ├── internal-jarakube-com-gateway.yaml
│   │       └── ...
│   ├── security/
│   │   ├── vault/
│   │   │   ├── namespace.yaml
│   │   │   ├── vault-values.yaml
│   │   │   ├── vault-virtual-service.yaml
│   │   │   └── auto-unseal-shamir/
│   │   └── external-secret/
│   │       └── secret-stores/
│   │           └── secret-store.yaml
│   └── ...
└── apps/
    ├── develop/
    │   └── <application>/
    └── production/
        └── <application>/
```

---

## 🚀 Getting Started

### 1. **Read the Quick Start Guide**
Start with [QUICKSTART.md](./QUICKSTART.md) for hands-on examples of common tasks.

### 2. **Explore Examples**
Browse the [examples/](./examples/) directory for practical YAML configurations.

### 3. **Understand the Architecture**
Review [SKILL.md](./SKILL.md) for comprehensive documentation on all capabilities.

### 4. **Check Configuration**
See [config.yaml](./config.yaml) for default settings and project-specific configuration.

---

## 🔍 Finding Information

### By Task

| Task | Where to Look |
|------|---------------|
| Deploy new application | [QUICKSTART.md - Deploy a New Application](./QUICKSTART.md#1-deploy-a-new-application) |
| Create VirtualService | [VirtualService Examples](./examples/virtualservice-example.yaml) |
| Configure Gateway | [Gateway Examples](./examples/gateway-example.yaml) |
| Set up ExternalSecret | [ExternalSecret Examples](./examples/external-secret-example.yaml) |
| Configure Vault | [Vault Examples](./examples/vault-example.yaml) |
| Troubleshoot issues | [QUICKSTART.md - Debugging Guide](./QUICKSTART.md#-debugging-guide) |

### By Component

| Component | Documentation |
|-----------|---------------|
| Flux CD | [SKILL.md - Flux CD Management](./SKILL.md#flux-cd-management) |
| Istio | [SKILL.md - Istio Service Mesh](./SKILL.md#istio-service-mesh) |
| Vault | [SKILL.md - Vault Integration](./SKILL.md#vault-integration) |
| External Secrets | [SKILL.md - External Secrets](./SKILL.md#external-secrets) |
| Networking | [SKILL.md - Networking](./SKILL.md#networking) |

---

## 📖 Example Workflows

### Workflow 1: Deploy a New Application

1. **Create application manifests** (deployment, service, virtualservice)
2. **Create ExternalSecret** for application secrets
3. **Update Flux Kustomization** to include the new application
4. **Commit and push** changes to Git
5. **Flux automatically syncs** the changes to the cluster

**Files to create:**
- `apps/develop/my-app/deployment.yaml`
- `apps/develop/my-app/service.yaml`
- `apps/develop/my-app/virtual-service.yaml`
- `apps/develop/my-app/kustomization.yaml`
- `infrastructure/security/external-secret/all-external-secrets/develop/my-app-secret.yaml`

**Examples:**
- [VirtualService Example](./examples/virtualservice-example.yaml)
- [ExternalSecret Example](./examples/external-secret-example.yaml)
- [Flux Example](./examples/flux-example.yaml)

---

### Workflow 2: Add a New Domain

1. **Create Gateway** for the new domain
2. **Create Certificate** for TLS
3. **Configure DNS** to point to MetalLB IP
4. **Create VirtualServices** for applications on the domain
5. **Commit and push** changes

**Files to create:**
- `infrastructure/networking/istio-system/my-domain-gateway.yaml`
- `infrastructure/networking/istio-system/my-domain-certificate.yaml`

**Examples:**
- [Gateway Example](./examples/gateway-example.yaml)

---

### Workflow 3: Vault Setup

1. **Deploy Vault** with HA Raft storage
2. **Configure auto-unseal** with CronJob
3. **Set up OIDC** with Keycloak
4. **Create policies** and roles
5. **Store application secrets** in Vault
6. **Configure External Secrets** to sync from Vault

**Files to create:**
- `infrastructure/security/vault/vault-values.yaml`
- `infrastructure/security/vault/auto-unseal-shamir/cronjob.yaml`
- `infrastructure/security/vault/auto-unseal-shamir/rbac.yaml`
- `infrastructure/security/vault/auto-unseal-shamir/script-configmap.yaml`
- `infrastructure/security/external-secret/secret-stores/secret-store.yaml`

**Examples:**
- [Vault Example](./examples/vault-example.yaml)

---

## 🎓 Learning Path

### Level 1: Beginner
1. Read [QUICKSTART.md](./QUICKSTART.md)
2. Try the **Deploy a New Application** workflow
3. Explore the [examples/](./examples/) directory
4. Practice common commands from the cheat sheet

### Level 2: Intermediate
1. Read [SKILL.md](./SKILL.md) in full
2. Understand the project structure
3. Learn about Flux CD and GitOps principles
4. Practice troubleshooting common issues

### Level 3: Advanced
1. Customize the skill configuration
2. Extend the examples for your use cases
3. Contribute improvements to the skill
4. Automate complex workflows

---

## 🔧 Configuration Reference

The [config.yaml](./config.yaml) file contains default settings for the skill:

```yaml
# Domain configuration
domains:
  primary:
    - "*.jarakube.com"
    - "*.jarakube.eu"

# Namespace configuration
namespaces:
  infrastructure:
    - flux-system
    - istio-ingress-external
    - istio-ingress-internal
    - vault
  environments:
    - develop
    - production

# Gateway configuration
gateways:
  external:
    namespace: istio-ingress-external
    selector: istio: external-gateway
    domains: ["*.jarakube.eu"]
  internal:
    namespace: istio-ingress-internal
    selector: istio: internal-gateway
    domains: ["*.jarakube.com"]

# Vault configuration
vault:
  namespace: vault
  storage_class: rook-ceph-block
  storage_size: 15Gi
  ha_enabled: true
  auto_unseal:
    enabled: true
    schedule: "*/10 * * * *"
```

---

## 🆘 Troubleshooting

### Common Issues

| Issue | Solution | Documentation |
|-------|----------|---------------|
| Flux not syncing | Check GitRepository and Kustomization status | [QUICKSTART.md - Flux Troubleshooting](./QUICKSTART.md#7-flux-troubleshooting) |
| VirtualService not routing | Verify Gateway and VirtualService configuration | [QUICKSTART.md - Debugging Guide](./QUICKSTART.md#problem-application-not-accessible-via-domain) |
| ExternalSecret not syncing | Check ClusterSecretStore and Vault token | [QUICKSTART.md - External Secret Debugging](./QUICKSTART.md#problem-externalsecret-not-syncing) |
| Vault sealed | Use auto-unseal or manually unseal | [QUICKSTART.md - Vault Operations](./QUICKSTART.md#6-vault-operations) |

### Debug Commands

**Flux:**
```bash
flux get all -A
kubectl logs -n flux-system deploy/flux-controller -f
```

**Istio:**
```bash
kubectl get gateways,virtualservices -A
istioctl analyze -A
kubectl logs -n istio-system deploy/istiod -f
```

**Vault:**
```bash
kubectl exec -n vault deploy/vault -c vault -- vault status
kubectl logs -n vault deploy/vault -c vault -f
```

**External Secrets:**
```bash
kubectl get externalsecrets,clustersecretstores -A
kubectl logs -n external-secrets deploy/external-secrets -f
```

---

## 📞 Support

### Internal Resources
- **Project Documentation**: Check the Notion page linked in [README.md](../../../../README.md)
- **Network Topology**: See the mermaid diagram in [README.md](../../../../README.md)
- **Cluster Information**: Review the [clusters/](../../../../clusters/) directory

### External Resources
- [Flux CD Documentation](https://fluxcd.io/flux/docs/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Vault Documentation](https://www.vaultproject.io/docs)
- [External Secrets Documentation](https://external-secrets.io/docs/)
- [cert-manager Documentation](https://cert-manager.io/docs/)

---

## 🎯 Best Practices

### 1. **GitOps Principles**
- All changes go through Git
- Use meaningful commit messages
- Review changes before merging
- Test in develop before production

### 2. **Security**
- Never commit secrets to Git
- Use External Secrets for all sensitive data
- Enable TLS for all external traffic
- Use network policies to restrict access

### 3. **Reliability**
- Configure health checks for all deployments
- Set appropriate resource limits
- Monitor application logs
- Use readiness and liveness probes

### 4. **Maintainability**
- Use consistent naming conventions
- Document configuration requirements
- Keep manifests organized
- Use Kustomize for environment-specific configurations

---

## 📊 Quick Reference

### Namespaces

| Purpose | Namespaces |
|---------|------------|
| Infrastructure | flux-system, istio-ingress-external, istio-ingress-internal, istio-egress, vault, metallb-system, cert-manager |
| Environments | develop, production |
| Observability | monitoring, logging |
| Storage | rook-ceph |

### Domains

| Domain | Gateway | Purpose |
|--------|---------|---------|
| *.jarakube.com | istio-ingress-internal | Internal services |
| *.jarakube.eu | istio-ingress-external | External services |

### Key Components

| Component | Purpose | Namespace |
|-----------|---------|-----------|
| Flux CD | GitOps automation | flux-system |
| Istio | Service mesh | istio-system, istio-ingress-* |
| Vault | Secrets management | vault |
| External Secrets | Secret synchronization | external-secrets |
| cert-manager | TLS certificates | cert-manager |
| MetalLB | Load balancing | metallb-system |

---

## 🔗 Related Files

- [Main README](../../../../README.md) - Project overview and network topology
- [Flux System](../../../../flux-system/) - Flux CD configuration
- [Infrastructure](../../../../infrastructure/) - All infrastructure components
- [Apps](../../../../apps/) - Application deployments
- [Clusters](../../../../clusters/) - Cluster-specific configurations

---

## 📝 Version Information

- **Skill Version**: 1.0.0
- **Last Updated**: 2026-05-16
- **Project**: jaraco k8s-operations
- **Author**: Generated for jaraco project

---

## 🎉 Next Steps

1. **Start with the Quick Start Guide**: [QUICKSTART.md](./QUICKSTART.md)
2. **Explore Examples**: Browse the [examples/](./examples/) directory
3. **Read Full Documentation**: [SKILL.md](./SKILL.md)
4. **Try a Workflow**: Deploy a new application or configure a new domain
5. **Customize**: Adapt the examples for your specific needs
