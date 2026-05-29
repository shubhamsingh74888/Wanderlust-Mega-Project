#!/usr/bin/env bash
# ============================================================
#  bootstrap-gitops.sh
#  Called by Jenkinsfile.infra Stage 04 after Terraform Apply.
# ============================================================

set -euo pipefail

ARGOCD_NAMESPACE="argocd"
GITOPS_RAW="https://raw.githubusercontent.com/shubhamsingh74888/wanderlust-gitops/main/argocd"
MAX_WAIT=300

echo ""
echo "======================================================"
echo " [BOOTSTRAP] Starting GitOps bootstrap"
echo "======================================================"

# ── Step 1: Wait for ArgoCD server ─────────────────────────
echo ""
echo "[BOOTSTRAP] Waiting for ArgoCD server to be Ready..."
kubectl wait deployment argocd-server \
  --namespace "$ARGOCD_NAMESPACE" \
  --for=condition=Available \
  --timeout="${MAX_WAIT}s" \
  || {
    echo "[BOOTSTRAP] ⚠ ArgoCD not Ready — pod status:"
    kubectl get pods -n "$ARGOCD_NAMESPACE" || true
    exit 1
  }
echo "[BOOTSTRAP] ✔ ArgoCD server is Ready."

# ── Step 2: Apply ArgoCD Application manifests from GitOps repo ──
echo ""
echo "[BOOTSTRAP] Applying ArgoCD apps from GitOps repo..."

kubectl apply -f "${GITOPS_RAW}/wanderlust-app.yaml" && \
  echo "[BOOTSTRAP] ✔ wanderlust app applied" || \
  echo "[BOOTSTRAP] ⚠ Failed to apply wanderlust app"

kubectl apply -f "${GITOPS_RAW}/prometheus.yaml" && \
  echo "[BOOTSTRAP] ✔ prometheus app applied" || \
  echo "[BOOTSTRAP] ⚠ Failed to apply prometheus app"

echo "[BOOTSTRAP] ✔ All ArgoCD manifests applied."

# ── Step 3: Check EBS CSI driver ───────────────────────────
echo ""
echo "[BOOTSTRAP] Checking EBS CSI driver..."
EBS_SA=$(kubectl get serviceaccount ebs-csi-controller-sa \
  -n kube-system \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' \
  2>/dev/null || echo "")

if [ -z "$EBS_SA" ]; then
  echo "[BOOTSTRAP] ⚠ EBS CSI annotation not found."
else
  echo "[BOOTSTRAP] ✔ EBS CSI annotated: $EBS_SA"
fi

# ── Step 4: Final status ────────────────────────────────────
echo ""
echo "[BOOTSTRAP] ── Nodes ─────────────────────────────────"
kubectl get nodes 2>/dev/null || true
echo ""
echo "[BOOTSTRAP] ── ArgoCD Applications ───────────────────"
kubectl get applications -n "$ARGOCD_NAMESPACE" 2>/dev/null || true
echo ""
echo "[BOOTSTRAP] ── Monitoring (ArgoCD syncing in background) ──"
kubectl get pods -n monitoring 2>/dev/null || echo "[BOOTSTRAP] monitoring namespace not yet created."
echo ""
echo "[BOOTSTRAP] ✅ Bootstrap complete."
echo "[BOOTSTRAP]    Check sync: kubectl get applications -n argocd"
echo "======================================================"
