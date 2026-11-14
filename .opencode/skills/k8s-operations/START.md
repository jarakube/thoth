# 🚀 START HERE - Kubernetes Operations Skill

**Welcome to the k8s-operations skill for opencode!**

This is your starting point for managing the jaraco Kubernetes operations project with AI assistance.

---

## 🎯 Quick Start (Choose One)

### I need to **DO** something:

| Task | Command/Question | File |
|------|-----------------|------|
| Deploy a new app | "Deploy a new application to develop namespace" | [QUICKSTART.md - Task 1](./QUICKSTART.md#1-deploy-a-new-application) |
| Create VirtualService | "Create a VirtualService for my-app on jarakube.com" | [virtualservice-example.yaml](./examples/virtualservice-example.yaml) |
| Set up new domain | "Add a new domain mydomain.com to Istio" | [QUICKSTART.md - Task 3](./QUICKSTART.md#3-add-new-domain) |
| Configure Vault | "Set up Vault auto-unseal" | [vault-example.yaml](./examples/vault-example.yaml) |
| Create ExternalSecret | "Create an ExternalSecret for my app" | [external-secret-example.yaml](./examples/external-secret-example.yaml) |
| Update app image | "Update my-app to version 2.0.0" | [QUICKSTART.md - Task 2](./QUICKSTART.md#2-update-application-image) |

### I need to **LEARN** something:

| Topic | Resource | Time |
|-------|----------|------|
| Quick overview | [README.md](./README.md) | 10 min |
| Hands-on guide | [QUICKSTART.md](./QUICKSTART.md) | 30 min |
| Complete reference | [SKILL.md](./SKILL.md) | 1 hour |
| Find information | [INDEX.md](./INDEX.md) | 15 min |

### I need **HELP** with something:

| Issue | Resource | File |
|-------|----------|------|
| App not accessible | Debugging Guide | [QUICKSTART.md - Debugging](./QUICKSTART.md#-debugging-guide) |
| Flux not syncing | Flux Troubleshooting | [QUICKSTART.md - Task 7](./QUICKSTART.md#7-flux-troubleshooting) |
| ExternalSecret not syncing | ExternalSecret Debug | [QUICKSTART.md - Problem 2](./QUICKSTART.md#problem-externalsecret-not-syncing) |
| Vault sealed | Vault Operations | [QUICKSTART.md - Task 6](./QUICKSTART.md#6-vault-operations) |

---

## 🎬 5-Minute Quick Start

### Step 1: Ask a Simple Question
Try one of these:
```
"What namespaces are used in this project?"
"Show me an example VirtualService"
"How do I deploy a new application?"
```

### Step 2: Try a Common Task
```
"Create a VirtualService for test-app on jarakube.com"
```

### Step 3: Explore Examples
Browse the [examples/](./examples/) directory for practical configurations.

---

## 📋 Common Commands Cheat Sheet

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
```

### External Secrets
```bash
kubectl get externalsecrets,clustersecretstores -A  # List all ExternalSecrets
kubectl logs -n external-secrets deploy/external-secrets -f  # View logs
```

---

## 🎯 Most Common Tasks

### 1️⃣ Deploy a New Application
**Time:** 15-30 minutes

```bash
# 1. Create application directory
mkdir -p apps/develop/my-app

# 2. Create manifests (use examples as templates)
# See: QUICKSTART.md - Task 1

# 3. Commit and push
git add . && git commit -m "Add my-app" && git push
```

**Help:** [QUICKSTART.md - Task 1](./QUICKSTART.md#1-deploy-a-new-application)

---

### 2️⃣ Create a VirtualService
**Time:** 5-10 minutes

```yaml
# Basic VirtualService template
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

**Help:** [virtualservice-example.yaml](./examples/virtualservice-example.yaml)

---

### 3️⃣ Set Up ExternalSecret
**Time:** 5-10 minutes

```yaml
# Basic ExternalSecret template
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

**Help:** [external-secret-example.yaml](./examples/external-secret-example.yaml)

---

## 🔍 Troubleshooting Quick Guide

### Problem: Application not accessible
**Check:**
1. ✅ VirtualService exists: `kubectl get virtualservice -n <namespace>`
2. ✅ Gateway exists: `kubectl get gateway -n <gateway-namespace>`
3. ✅ Service exists: `kubectl get svc -n <namespace>`
4. ✅ Pods are running: `kubectl get pods -n <namespace>`
5. ✅ DNS is configured

**Help:** [QUICKSTART.md - Debugging Guide](./QUICKSTART.md#-debugging-guide)

---

### Problem: ExternalSecret not syncing
**Check:**
1. ✅ ExternalSecret exists: `kubectl get externalsecret -n <namespace>`
2. ✅ ClusterSecretStore exists: `kubectl get clustersecretstore vault-backend`
3. ✅ Vault token secret exists: `kubectl get secret -n vault vault-token`
4. ✅ Vault is accessible: `kubectl exec -n vault deploy/vault -c vault -- vault status`

**Help:** [QUICKSTART.md - Problem 2](./QUICKSTART.md#problem-externalsecret-not-syncing)

---

### Problem: Flux not syncing
**Check:**
1. ✅ GitRepository is healthy: `flux get sources git -n flux-system`
2. ✅ Kustomization is healthy: `flux get kustomizations -n <namespace>`
3. ✅ Flux controller is running: `kubectl get pods -n flux-system`
4. ✅ Changes are committed and pushed

**Help:** [QUICKSTART.md - Task 7](./QUICKSTART.md#7-flux-troubleshooting)

---

## 📚 Learning Resources

### By Time Available

| Time | Activity | Outcome |
|------|----------|---------|
| 5 min | Read this file + ask a simple question | Understand basic usage |
| 15 min | Try a common task from cheat sheet | Complete a simple task |
| 30 min | Read QUICKSTART.md | Learn workflows and troubleshooting |
| 1 hour | Complete a full task (deploy app) | Gain practical experience |
| 2+ hours | Read SKILL.md + INDEX.md | Master the platform |

### By Role

| Role | Recommended Path | Focus |
|------|------------------|-------|
| **Developer** | QUICKSTART.md → Examples → SKILL.md | Deploy apps, troubleshoot |
| **DevOps** | SKILL.md → INDEX.md → Examples | Manage infrastructure |
| **New Team Member** | README.md → QUICKSTART.md → Examples | Learn the basics |
| **Expert** | INDEX.md → config.yaml → Customize | Extend and customize |

---

## 🎯 Project Overview

### Architecture
- **Cluster:** jarakube (1 control plane + 8 worker nodes)
- **Service Mesh:** Istio
- **Secrets:** Vault with auto-unseal
- **GitOps:** Flux CD
- **Storage:** Rook Ceph
- **Observability:** Prometheus, Grafana, Loki

### Key Domains
- `*.jarakube.com` - Internal services (istio-ingress-internal)
- `*.jarakube.eu` - External services (istio-ingress-external)

### Namespaces
- **Infrastructure:** flux-system, istio-ingress-*, vault, metallb-system, cert-manager
- **Environments:** develop, production

---

## 🔗 Quick Navigation

| Need | Go To | Time |
|------|-------|------|
| **Start here** | This file (START.md) | Now |
| **Quick tasks** | QUICKSTART.md | 5 min |
| **Examples** | examples/ | 10 min |
| **Complete reference** | SKILL.md | 30 min |
| **Find anything** | INDEX.md | 15 min |
| **Package info** | README.md | 10 min |

---

## 💡 Pro Tips

### 1. Use Natural Language
You can ask opencode in plain English:
```
"How do I create a VirtualService for my app?"
"My ExternalSecret isn't working, help me debug"
"Show me an example Gateway configuration"
```

### 2. Start Simple
Begin with small, specific questions before tackling complex tasks.

### 3. Use the Examples
The [examples/](./examples/) directory contains ready-to-use configurations.

### 4. Follow the Workflows
The QUICKSTART.md contains complete workflows for common tasks.

### 5. Bookmark Key Files
- [QUICKSTART.md](./QUICKSTART.md) - For common tasks
- [INDEX.md](./INDEX.md) - For finding information
- [examples/](./examples/) - For configuration templates

---

## 🚨 Emergency Procedures

### Vault is Sealed
```bash
# Manual unseal
kubectl exec -it -n vault deploy/vault -c vault -- vault operator unseal <key>

# Or trigger auto-unseal job
kubectl create job --from=cronjob/vault-auto-unseal -n vault manual-unseal
```

### Flux Not Working
```bash
# Restart Flux controller
kubectl rollout restart -n flux-system deploy/flux-controller

# Check Flux installation
flux check --pre
```

### Application Down
```bash
# Check pods
kubectl get pods -n <namespace>

# Check logs
kubectl logs -n <namespace> <pod-name> -f

# Check events
kubectl get events -n <namespace> --sort-by='.metadata.creationTimestamp'
```

---

## 🎉 You're Ready!

### Next Steps:
1. **Try a simple question** (see above)
2. **Complete a quick task** (deploy an app, create a VirtualService)
3. **Explore the examples** for inspiration
4. **Read the QUICKSTART.md** for comprehensive guidance

### Remember:
- All changes go through Git
- Test in develop before production
- Use External Secrets for sensitive data
- Monitor after making changes

---

## 📞 Need More Help?

### Ask opencode:
```
"What should I do next?"
"Explain the project architecture"
"Show me the most common commands"
```

### Check Documentation:
- [README.md](./README.md) - Package overview
- [QUICKSTART.md](./QUICKSTART.md) - Hands-on guide
- [INDEX.md](./INDEX.md) - Find information
- [SKILL.md](./SKILL.md) - Complete reference

### Browse Examples:
- [VirtualService Examples](./examples/virtualservice-example.yaml)
- [Gateway Examples](./examples/gateway-example.yaml)
- [Flux Examples](./examples/flux-example.yaml)
- [Vault Examples](./examples/vault-example.yaml)
- [ExternalSecret Examples](./examples/external-secret-example.yaml)

---

## ✨ Final Checklist

Before you start, make sure you have:

- [x] Access to the Kubernetes cluster
- [x] Git repository access
- [x] opencode installed and configured
- [x] Basic Kubernetes knowledge
- [x] This skill package in `.opencode/skills/k8s-operations/`

---

## 🎯 Common First Questions

### Q: What can this skill help me with?
**A:** Deploying applications, managing Istio resources, configuring Vault, setting up External Secrets, troubleshooting issues, and more.

### Q: How do I get started?
**A:** Start with a simple question like "Show me an example VirtualService" or try the 5-minute quick start above.

### Q: Where can I find examples?
**A:** In the [examples/](./examples/) directory. Each file contains multiple practical examples.

### Q: How do I deploy a new application?
**A:** See [QUICKSTART.md - Task 1](./QUICKSTART.md#1-deploy-a-new-application) for a complete step-by-step guide.

### Q: What if I get stuck?
**A:** Use the debugging guides in QUICKSTART.md or ask opencode for specific help.

---

## 🏁 Ready, Set, Go!

**Start by asking opencode a question or trying one of the quick start tasks above!**

The k8s-operations skill is designed to make your Kubernetes operations easier, faster, and more reliable. Whether you're deploying a new application, troubleshooting an issue, or learning about the platform, this skill has you covered.

**Happy Kubernetes operations! 🎉**

---

*Last updated: 2026-05-16*
*Version: 1.0.0*
*Skill: k8s-operations*
