#!/bin/bash
# Day-Zero cluster bootstrap — run ONCE after EKS is up.
# Deploys ArgoCD via helm CLI to avoid Terraform API race condition.
# ArgoCD then manages ALL other apps (Prometheus, Wanderlust) via GitOps.
set -euo pipefail

CLUSTER_NAME="wanderlust-prod-eks"
REGION="ap-south-1"
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="7.4.5"
GITOPS_REPO="https://github.com/shubhamsingh74888/wanderlust-gitops.git"

echo "=== Day-Zero Bootstrap: $(date) ==="

# 1. Verify cluster is reachable
echo "[1/6] Checking EKS cluster..."
aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
  --query 'cluster.status' --output text | grep -q ACTIVE \
  || { echo "ERROR: Cluster not ACTIVE. Run terraform apply first."; exit 1; }

# 2. Update kubeconfig
echo "[2/6] Updating kubeconfig..."
aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$REGION"

# 3. Wait for nodes to be ready
echo "[3/6] Waiting for nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# 4. Install ArgoCD via helm (not Terraform — avoids API race condition)
echo "[4/6] Installing ArgoCD ${ARGOCD_VERSION}..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NAMESPACE" \
  --create-namespace \
  --version "$ARGOCD_VERSION" \
  --set server.service.type=LoadBalancer \
  --wait \
  --timeout 5m

echo "[4/6] ✔ ArgoCD installed."

# 5. Wait for ArgoCD server to be available
echo "[5/6] Waiting for ArgoCD server..."
kubectl -n "$ARGOCD_NAMESPACE" wait \
  --for=condition=available deployment/argocd-server \
  --timeout=120s

# 6. Apply the ArgoCD Application manifest (wanderlust-app.yaml)
# This tells ArgoCD to watch the gitops repo and sync everything
echo "[6/6] Registering Wanderlust Application with ArgoCD..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wanderlust
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${GITOPS_REPO}
    targetRevision: main
    path: kubernetes/production
  destination:
    server: https://kubernetes.default.svc
    namespace: wanderlust
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo ""
echo "=========================================================="
echo "  BOOTSTRAP COMPLETE"
echo "=========================================================="
ARGOCD_URL=$(kubectl -n argocd get svc argocd-server \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)
echo "  ArgoCD URL      : http://${ARGOCD_URL}"
echo "  ArgoCD user     : admin"
echo "  ArgoCD password : ${ARGOCD_PASS}"
echo "  (Change this password immediately after first login)"
echo "=========================================================="
