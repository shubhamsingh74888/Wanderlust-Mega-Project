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

