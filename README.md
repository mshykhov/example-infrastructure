# Test Infrastructure

GitOps infrastructure repository. App-of-Apps pattern.

## Structure

```
infrastructure/
├── bootstrap/
│   └── root.yaml                      # Entry point (apply manually once)
├── apps/
│   ├── Chart.yaml
│   ├── values.yaml                    # Common settings
│   └── templates/                     # One file per Application
│       ├── metallb.yaml               # Wave 1
│       ├── metallb-config.yaml        # Wave 2
│       └── longhorn.yaml              # Wave 3
└── manifests/
    ├── argocd-config/
    │   └── repository-secret.example.yaml  # Template for private repos
    └── metallb-config/
        └── config.yaml                # IPAddressPool + L2Advertisement
```

## Bootstrap

### 1. Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.5/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```

### 2. Connect Repository (private repos only)

For **public** repos — skip this step.

For **private** repos:
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "argocd" -f ~/.ssh/argocd-key -N ""

# Add public key to GitHub repo → Settings → Deploy keys
cat ~/.ssh/argocd-key.pub

# Create secret from template
cp manifests/argocd-config/repository-secret.example.yaml /tmp/repository-secret.yaml
# Edit /tmp/repository-secret.yaml - paste your private key
kubectl apply -f /tmp/repository-secret.yaml
rm /tmp/repository-secret.yaml  # Don't leave secrets on disk!
```

### 3. Apply Root Application

```bash
kubectl apply -f bootstrap/root.yaml
```

### 4. Access ArgoCD

```bash
# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 (admin / <password>)
```

## How It Works

```
kubectl apply -f bootstrap/root.yaml
              │
              ▼
┌─────────────────────────────────────────┐
│  Root Application                       │
│  syncs apps/ as Helm chart              │
│  (each file in templates/ = Application)│
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│  Child Applications (by sync-wave)      │
│                                         │
│  Wave 1: metallb         → Helm chart   │
│  Wave 2: metallb-config  → Manifests    │
│  Wave 3: longhorn        → Helm chart   │
└─────────────────────────────────────────┘
```

## Adding New Components

### Option 1: Simple (current approach)

Create new file in `apps/templates/`:

```yaml
# apps/templates/traefik.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "4"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://traefik.github.io/charts
    chart: traefik
    targetRevision: "26.0.0"
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: traefik-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Option 2: ApplicationSet (for many similar apps)

When you have many apps with similar structure, use ApplicationSet with Git Directory Generator.
See: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/

## Configuration

### MetalLB IP Range

Edit `manifests/metallb-config/config.yaml`:
```yaml
spec:
  addresses:
    - 192.168.8.240-192.168.8.250  # Change to your network
```

## Phase 1 Components

| Component | Version | Wave | Type | Docs |
|-----------|---------|------|------|------|
| MetalLB | 0.15.2 | 1 | Helm | https://metallb.io/ |
| MetalLB Config | - | 2 | Manifests | https://metallb.io/configuration/ |
| Longhorn | 1.10.1 | 3 | Helm | https://longhorn.io/ |

## Verification

```bash
# Check all apps
kubectl get applications -n argocd

# Check MetalLB
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system

# Check Longhorn
kubectl get pods -n longhorn-system

# Test LoadBalancer
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer
kubectl get svc nginx  # Should have EXTERNAL-IP
kubectl delete deploy nginx && kubectl delete svc nginx
```

## Links

- [ArgoCD App-of-Apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [ArgoCD Private Repos](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/)
- [ArgoCD Declarative Setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [ArgoCD ApplicationSet](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [MetalLB](https://metallb.io/)
- [Longhorn](https://longhorn.io/)
