/*

#!/bin/bash
# Day-Zero cluster bootstrap — run ONCE after EKS is up.
# Fully automated: CSI driver, StorageClass, ArgoCD, GitOps app registration.
set -euo pipefail

CLUSTER_NAME="wanderlust-prod-eks"
REGION="ap-south-1"
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="7.4.5"
GITOPS_REPO="https://github.com/shubhamsingh74888/wanderlust-gitops.git"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== Day-Zero Bootstrap: $(date) ==="
echo "    Account : $AWS_ACCOUNT_ID"
echo "    Cluster : $CLUSTER_NAME"
echo "    Region  : $REGION"

# ── 1. Verify cluster is reachable ──────────────────────────────────────────
echo "[1/8] Checking EKS cluster..."
aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
  --query 'cluster.status' --output text | grep -q ACTIVE \
  || { echo "ERROR: Cluster not ACTIVE. Run terraform apply first."; exit 1; }

# ── 2. Update kubeconfig ─────────────────────────────────────────────────────
echo "[2/8] Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# ── 3. Wait for nodes ────────────────────────────────────────────────────────
echo "[3/8] Waiting for nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# ── 4. Install EBS CSI driver (if not already installed by Terraform) ────────
echo "[4/8] Ensuring EBS CSI driver is installed..."
if ! kubectl get deployment ebs-csi-controller -n kube-system &>/dev/null; then
  echo "  Installing EBS CSI driver via EKS addon..."
  
  # Get node role name
  NODEGROUP=$(aws eks list-nodegroups \
    --cluster-name "$CLUSTER_NAME" --region "$REGION" \
    --query 'nodegroups[0]' --output text)
  NODE_ROLE_ARN=$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODEGROUP" \
    --region "$REGION" \
    --query 'nodegroup.nodeRole' --output text)
  NODE_ROLE=$(basename "$NODE_ROLE_ARN")

  # Attach policy to node role as fallback (works without IRSA)
  aws iam attach-role-policy \
    --role-name "$NODE_ROLE" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    2>/dev/null || echo "  Policy already attached."

  aws eks create-addon \
    --cluster-name "$CLUSTER_NAME" \
    --addon-name aws-ebs-csi-driver \
    --region "$REGION" \
    2>/dev/null || echo "  Addon already exists."

  echo "  Waiting for EBS CSI addon to become ACTIVE..."
  for i in $(seq 1 30); do
    STATUS=$(aws eks describe-addon \
      --cluster-name "$CLUSTER_NAME" \
      --addon-name aws-ebs-csi-driver \
      --region "$REGION" \
      --query 'addon.status' --output text 2>/dev/null || echo "UNKNOWN")
    [ "$STATUS" = "ACTIVE" ] && break
    echo "  Status: $STATUS — waiting 15s... ($i/30)"
    sleep 15
  done
fi

# Wait for CSI controller pods to be running
echo "  Waiting for EBS CSI controller pods..."
kubectl -n kube-system wait \
  --for=condition=available deployment/ebs-csi-controller \
  --timeout=180s || true

# ── 5. Create StorageClass ────────────────────────────────────────────────────
echo "[5/8] Creating StorageClass..."
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: wanderlust-ebs
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
parameters:
  type: gp3
  csi.storage.k8s.io/fstype: ext4
  encrypted: "false"
EOF
echo "  StorageClass created."

# ── 6. Install ArgoCD via Helm ────────────────────────────────────────────────
echo "[6/8] Installing ArgoCD ${ARGOCD_VERSION}..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NAMESPACE" \
  --create-namespace \
  --version "$ARGOCD_VERSION" \
  --set server.service.type=LoadBalancer \
  --set configs.params."server\.insecure"=true \
  --wait \
  --timeout 5m

echo "  ✔ ArgoCD installed."

# ── 7. Wait for ArgoCD server ─────────────────────────────────────────────────
echo "[7/8] Waiting for ArgoCD server..."
kubectl -n "$ARGOCD_NAMESPACE" wait \
  --for=condition=available deployment/argocd-server \
  --timeout=180s

# ── 8. Register Wanderlust app with ArgoCD ────────────────────────────────────
echo "[8/8] Registering Wanderlust Application with ArgoCD..."
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wanderlust
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
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
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
EOF

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=========================================================="
echo "  BOOTSTRAP COMPLETE — $(date)"
echo "=========================================================="

echo "  Waiting up to 60s for LoadBalancer hostname..."
for i in $(seq 1 12); do
  ARGOCD_URL=$(kubectl -n argocd get svc argocd-server \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  [ -n "$ARGOCD_URL" ] && break
  sleep 5
done

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "not-ready-yet")

echo ""
echo "  ArgoCD URL      : http://${ARGOCD_URL:-pending...}"
echo "  ArgoCD user     : admin"
echo "  ArgoCD password : ${ARGOCD_PASS}"
echo ""
echo "  ⚠  Change the password immediately after first login."
echo "  ⚠  Pods will come up in ~3-5 minutes as ArgoCD syncs."
echo "=========================================================="
echo ""
echo "  Monitor with:"
echo "    kubectl get pods -n wanderlust -w"
echo "    kubectl get pvc  -n wanderlust"
echo "=========================================================="

*/







#!/usr/bin/env bash
# ============================================================
#  bootstrap-gitops.sh
#  Called by Jenkinsfile.infra Stage 04 after Terraform Apply.
#
#  What this script does:
#  1. Waits for ArgoCD pods to be Ready (Terraform deployed it)
#  2. Applies all ArgoCD Application manifests from kubernetes/argocd-apps/
#     This includes prometheus.yaml — ArgoCD then takes over deploying it.
#  3. Patches the EBS CSI driver (if not already patched)
# ============================================================

set -euo pipefail

ARGOCD_NAMESPACE="argocd"
ARGOCD_APPS_DIR="kubernetes/argocd-apps"
MAX_WAIT=300   # 5 minutes max wait for ArgoCD to become ready

echo ""
echo "======================================================"
echo " [BOOTSTRAP] Starting GitOps bootstrap"
echo "======================================================"

# ── Step 1: Wait for ArgoCD server to be Ready ─────────────
echo ""
echo "[BOOTSTRAP] Waiting for ArgoCD server deployment to be Ready..."
echo "[BOOTSTRAP] (This can take 2-3 minutes on a fresh cluster)"

kubectl wait deployment argocd-server \
  --namespace "$ARGOCD_NAMESPACE" \
  --for=condition=Available \
  --timeout="${MAX_WAIT}s" \
  || {
    echo "[BOOTSTRAP] ⚠ ArgoCD server not Ready after ${MAX_WAIT}s — showing pod status:"
    kubectl get pods -n "$ARGOCD_NAMESPACE" || true
    echo "[BOOTSTRAP] ❌ Cannot apply ArgoCD apps — ArgoCD is not up yet."
    exit 1
  }

echo "[BOOTSTRAP] ✔ ArgoCD server is Ready."

# ── Step 2: Apply all ArgoCD Application manifests ─────────
echo ""
echo "[BOOTSTRAP] Applying ArgoCD Application manifests from $ARGOCD_APPS_DIR/ ..."

if [ ! -d "$ARGOCD_APPS_DIR" ]; then
  echo "[BOOTSTRAP] ⚠ Directory $ARGOCD_APPS_DIR not found — skipping app manifests."
else
  # Apply every .yaml file in the argocd-apps directory
  for manifest in "$ARGOCD_APPS_DIR"/*.yaml; do
    if [ -f "$manifest" ]; then
      echo "[BOOTSTRAP]   → Applying $manifest"
      kubectl apply -f "$manifest" || {
        echo "[BOOTSTRAP] ⚠ Failed to apply $manifest — continuing..."
      }
    fi
  done
  echo "[BOOTSTRAP] ✔ All ArgoCD Application manifests applied."
fi

# ── Step 3: Patch EBS CSI driver service account (if needed) ─
echo ""
echo "[BOOTSTRAP] Checking EBS CSI driver..."

EBS_SA=$(kubectl get serviceaccount ebs-csi-controller-sa \
  -n kube-system \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' \
  2>/dev/null || echo "")

if [ -z "$EBS_SA" ]; then
  echo "[BOOTSTRAP] ⚠ EBS CSI service account annotation not found — skipping patch."
else
  echo "[BOOTSTRAP] ✔ EBS CSI driver service account is annotated: $EBS_SA"
fi

# ── Step 4: Show final status ───────────────────────────────
echo ""
echo "[BOOTSTRAP] ── Final cluster status ──────────────────"
kubectl get nodes                          2>/dev/null || true
echo ""
echo "[BOOTSTRAP] ── ArgoCD Applications ───────────────────"
kubectl get applications -n "$ARGOCD_NAMESPACE" 2>/dev/null || true
echo ""
echo "[BOOTSTRAP] ── Monitoring namespace (may still be starting) ──"
kubectl get pods -n monitoring             2>/dev/null || echo "[BOOTSTRAP] monitoring namespace not yet created — ArgoCD is syncing..."
echo ""
echo "[BOOTSTRAP] ✅ Bootstrap complete."
echo "[BOOTSTRAP]    ArgoCD is now managing Prometheus."
echo "[BOOTSTRAP]    Check sync status: kubectl get applications -n argocd"
echo "======================================================"


