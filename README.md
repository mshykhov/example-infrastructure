# Example Infrastructure

GitOps infrastructure. App-of-Apps pattern.

## Bootstrap

```bash
# 1. ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.5/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 2. SSH ключ
ssh-keygen -t ed25519 -C "argocd" -f ~/.ssh/argocd -N ""
cat ~/.ssh/argocd.pub
# → GitHub repo → Settings → Deploy keys → Add

# 3. Секрет
kubectl create secret generic repo-example-infrastructure \
  --from-literal=type=git \
  --from-literal=url=git@github.com:mshykhov/example-infrastructure.git \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd \
  -n argocd
kubectl label secret repo-example-infrastructure argocd.argoproj.io/secret-type=repository -n argocd

# 4. GitOps
kubectl apply -f https://raw.githubusercontent.com/mshykhov/example-infrastructure/main/bootstrap/root.yaml

# 5. Проверка
kubectl get applications -n argocd -w
```

## Components

| Component | Version | Wave |
|-----------|---------|------|
| MetalLB | 0.15.2 | 1 |
| MetalLB Config | - | 2 |
| Longhorn | 1.10.1 | 3 |

## Verification

```bash
kubectl get applications -n argocd
kubectl get pods -n metallb-system
kubectl get pods -n longhorn-system
kubectl get ipaddresspool -n metallb-system
```
