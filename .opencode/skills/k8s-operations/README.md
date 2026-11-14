# Kubernetes Operations Skill for opencode

**🎯 Purpose**: This skill provides comprehensive assistance for managing the **jaraco k8s-operations** project, enabling opencode to help with Flux CD deployments, Istio service mesh configuration, Vault integration, External Secrets management, and all other Kubernetes operations tasks.

---

## 📦 What's Included

This skill package contains:

```
k8s-operations/
├── SKILL.md              # Main skill documentation with all capabilities
├── QUICKSTART.md         # Hands-on guide with common tasks and commands
├── config.yaml           # Skill-specific configuration and defaults
├── INDEX.md              # Comprehensive index and navigation guide
├── README.md             # This file
└── examples/
    ├── virtualservice-example.yaml   # Istio VirtualService examples
    ├── gateway-example.yaml           # Istio Gateway examples
    ├── flux-example.yaml              # Flux CD configuration examples
    ├── vault-example.yaml             # Vault deployment and configuration
    └── external-secret-example.yaml   # External Secrets examples
```

---

## 🚀 Quick Start

### For Users

To use this skill with opencode, simply ask questions related to the k8s-operations project:

```
# Deploy a new application
"How do I deploy a new application to the develop namespace?"

# Create a VirtualService
"Create a VirtualService for my-app on jarakube.com"

# Configure Vault
"Set up Vault auto-unseal with the existing configuration"

# Troubleshoot issues
"My ExternalSecret isn't syncing, help me debug"
```

### For Developers

To extend or customize this skill:

1. **Read the documentation**: Start with [SKILL.md](./SKILL.md) to understand all capabilities
2. **Explore examples**: Check the [examples/](./examples/) directory for practical configurations
3. **Customize configuration**: Modify [config.yaml](./config.yaml) for project-specific settings
4. **Add new examples**: Create new YAML files in the [examples/](./examples/) directory

---

## 🎯 Key Features

### ✅ Flux CD Management
- Deploy applications from Git repositories
- Manage Helm charts and repositories
- Configure multi-environment deployments (develop, production)
- Set up automatic image updates
- Troubleshoot sync issues

### ✅ Istio Service Mesh
- Create and manage Gateways (external, internal)
- Configure VirtualServices for application routing
- Set up TLS termination and HTTPS redirection
- Implement advanced traffic management (canary, A/B testing)
- Troubleshoot connectivity issues

### ✅ Vault Integration
- Deploy Vault with HA Raft storage
- Configure auto-unseal with CronJobs
- Set up OIDC authentication with Keycloak
- Create and manage secrets
- Configure certificate authority

### ✅ External Secrets
- Set up ClusterSecretStore for Vault backend
- Create ExternalSecret resources for applications
- Configure automatic secret refresh
- Troubleshoot sync issues

### ✅ Networking
- Configure MetalLB for load balancing
- Manage IP address pools
- Set up DNS configuration
- Configure network policies

### ✅ Certificate Management
- Configure cert-manager for automatic TLS
- Create wildcard certificates
- Set up ClusterIssuers
- Manage certificate renewal

---

## 📚 Documentation Structure

### 📖 Core Documentation

| File | Purpose | Audience |
|------|---------|----------|
| [SKILL.md](./SKILL.md) | Complete skill reference with all capabilities, commands, and workflows | Advanced users, developers |
| [QUICKSTART.md](./QUICKSTART.md) | Practical guide with common tasks, commands, and troubleshooting | All users |
| [INDEX.md](./INDEX.md) | Comprehensive navigation and reference guide | All users |

### 📝 Examples

| File | Description | Use Case |
|------|-------------|----------|
| [virtualservice-example.yaml](./examples/virtualservice-example.yaml) | VirtualService configurations for various scenarios | Creating application routing |
| [gateway-example.yaml](./examples/gateway-example.yaml) | Gateway configurations for different domains | Setting up new domains |
| [flux-example.yaml](./examples/flux-example.yaml) | Flux CD configurations and Helm releases | Deploying applications |
| [vault-example.yaml](./examples/vault-example.yaml) | Vault deployment, auto-unseal, and OIDC setup | Secrets management |
| [external-secret-example.yaml](./examples/external-secret-example.yaml) | ExternalSecret configurations | Application secrets |

### ⚙️ Configuration

| File | Description | Customizable |
|------|-------------|--------------|
| [config.yaml](./config.yaml) | Skill-specific defaults and project configuration | Yes |

---

## 🎓 Learning Path

### Level 1: Getting Started (1-2 hours)
1. Read [QUICKSTART.md](./QUICKSTART.md)
2. Try the **Deploy a New Application** workflow
3. Explore the [examples/](./examples/) directory
4. Practice common commands from the cheat sheet

### Level 2: Intermediate (1 day)
1. Read [SKILL.md](./SKILL.md) in full
2. Understand the project structure and architecture
3. Learn about Flux CD and GitOps principles
4. Practice troubleshooting common issues
5. Deploy a new application from scratch

### Level 3: Advanced (1 week)
1. Customize the skill configuration
2. Extend the examples for your use cases
3. Automate complex workflows
4. Contribute improvements to the skill
5. Set up monitoring and observability

---

## 🔧 Customization

### Adding New Examples

To add a new example:

1. Create a new YAML file in the [examples/](./examples/) directory
2. Follow the existing format with clear comments and multiple variations
3. Reference the example in the documentation

Example structure:
```yaml
# Description of the example
# This example shows how to [do something]

apiVersion: v1
kind: Resource
metadata:
  name: example
spec:
  # Configuration
  key: value

---
# Additional variations or related examples
```

### Updating Configuration

To customize the skill behavior:

1. Edit [config.yaml](./config.yaml)
2. Update default values for your project
3. Add project-specific settings

Example configuration:
```yaml
# Project-specific settings
project:
  name: k8s-operations
  primary_cluster: jarakube
  
# Domain configuration
domains:
  primary:
    - "*.jarakube.com"
    - "*.jarakube.eu"

# Default resource limits
defaults:
  resources:
    limits:
      cpu: 1000m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi
```

---

## 🆘 Troubleshooting

### Common Issues

| Issue | Solution | Documentation |
|-------|----------|---------------|
| Can't find skill | Ensure skill is in `.opencode/skills/k8s-operations/` | [INDEX.md](./INDEX.md) |
| Commands not working | Check opencode version and skill loading | [SKILL.md](./SKILL.md) |
| Examples not applicable | Customize examples for your project | [config.yaml](./config.yaml) |

### Debugging

**Check skill loading:**
```bash
# List available skills
ls -la .opencode/skills/

# Check skill files
ls -la .opencode/skills/k8s-operations/
```

**Test skill functionality:**
```
# Ask a simple question
"What namespaces are used in the k8s-operations project?"

# Request a specific task
"Create a VirtualService for test-app on jarakube.com"
```

---

## 📊 Project Overview

### Architecture

The k8s-operations project manages a Kubernetes cluster with:

- **Multi-node architecture**: 1 control plane + 8 worker nodes (including GPU nodes)
- **Service mesh**: Istio for traffic management
- **Secrets management**: Vault with auto-unseal
- **GitOps**: Flux CD for automated deployments
- **Observability**: Prometheus, Grafana, Loki
- **Storage**: Rook Ceph for persistent storage

### Key Domains

| Domain | Purpose | Gateway |
|--------|---------|---------|
| *.jarakube.com | Internal services | istio-ingress-internal |
| *.jarakube.eu | External services | istio-ingress-external |

### Network Topology

See the mermaid diagram in the main [README.md](../../../../README.md) for the complete network topology.

---

## 🔗 Related Resources

### Internal
- [Main Project README](../../../../README.md) - Network topology and overview
- [Flux System Configuration](../../../../flux-system/) - GitOps setup
- [Infrastructure Components](../../../../infrastructure/) - All infrastructure manifests
- [Application Deployments](../../../../apps/) - Application configurations

### External
- [Flux CD Documentation](https://fluxcd.io/flux/docs/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Vault Documentation](https://www.vaultproject.io/docs)
- [External Secrets Documentation](https://external-secrets.io/docs/)
- [cert-manager Documentation](https://cert-manager.io/docs/)

---

## 📞 Support

### Getting Help

1. **Check the documentation**: Start with [QUICKSTART.md](./QUICKSTART.md) or [INDEX.md](./INDEX.md)
2. **Browse examples**: Look at the [examples/](./examples/) directory
3. **Ask opencode**: Use natural language to ask questions
4. **Check project docs**: Review the main [README.md](../../../../README.md)

### Common Questions

**Q: How do I deploy a new application?**
A: See [QUICKSTART.md - Deploy a New Application](./QUICKSTART.md#1-deploy-a-new-application)

**Q: How do I create a VirtualService?**
A: See [VirtualService Examples](./examples/virtualservice-example.yaml)

**Q: How do I configure Vault?**
A: See [Vault Examples](./examples/vault-example.yaml)

**Q: How do I troubleshoot Flux issues?**
A: See [QUICKSTART.md - Flux Troubleshooting](./QUICKSTART.md#7-flux-troubleshooting)

---

## 🎉 Contributing

### How to Contribute

1. **Fork the repository** (if applicable)
2. **Create a feature branch**
3. **Make your changes** to the skill files
4. **Test your changes** by using opencode with the updated skill
5. **Submit a pull request**

### Contribution Guidelines

- Follow existing code style and conventions
- Add clear comments and documentation
- Test examples before committing
- Update the INDEX.md if adding new files
- Keep examples practical and project-relevant

### What to Contribute

- New examples for common tasks
- Improved documentation
- Bug fixes in examples
- New workflows and use cases
- Better organization and navigation

---

## 📝 Release Notes

### Version 1.0.0 (2026-05-16)

**Initial Release**
- Complete skill documentation for k8s-operations
- Quick start guide with practical examples
- Comprehensive examples for all major components
- Configuration file with project defaults
- Navigation index for easy access

**Features:**
- Flux CD management
- Istio service mesh configuration
- Vault integration and auto-unseal
- External Secrets management
- Networking and certificate management

---

## 🔒 License

This skill is provided as-is for use with the jaraco k8s-operations project. The content is based on the project's existing configuration and is intended for internal use.

---

## 📞 Contact

For questions or issues related to this skill:

1. **Check the documentation** first
2. **Ask opencode** using natural language
3. **Review the project** configuration in the repository
4. **Consult the team** for project-specific questions

---

## 🎯 Quick Commands Reference

### Flux CD
```bash
flux get all -A                    # Check all Flux resources
flux reconcile kustomization <name> -n <namespace>  # Force sync
kubectl logs -n flux-system deploy/flux-controller -f  # View logs
```

### Istio
```bash
kubectl get gateways,virtualservices -A  # List all Istio resources
istioctl analyze -A                     # Analyze configuration
kubectl logs -n istio-system deploy/istiod -f  # View Istio logs
```

### Vault
```bash
kubectl exec -n vault deploy/vault -c vault -- vault status  # Check status
kubectl exec -n vault deploy/vault -c vault -- vault kv list kv/jaraco  # List secrets
kubectl logs -n vault deploy/vault -c vault -f  # View logs
```

### External Secrets
```bash
kubectl get externalsecrets,clustersecretstores -A  # List all ExternalSecrets
kubectl logs -n external-secrets deploy/external-secrets -f  # View logs
kubectl describe externalsecret <name> -n <namespace>  # Check status
```

---

## 🚀 Ready to Start?

Begin by reading the [QUICKSTART.md](./QUICKSTART.md) guide, or jump directly to:

- [Deploy a new application](./QUICKSTART.md#1-deploy-a-new-application)
- [Create a VirtualService](./examples/virtualservice-example.yaml)
- [Configure Vault auto-unseal](./examples/vault-example.yaml)
- [Set up External Secrets](./examples/external-secret-example.yaml)

**Happy Kubernetes operations! 🎉**
