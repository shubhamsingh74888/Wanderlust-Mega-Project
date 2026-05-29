#!/usr/bin/env bash
# ============================================================
#  bootstrap-gitops.sh
#  Called by Jenkinsfile.infra Stage 04 after Terraform Apply.
# ============================================================

set -euo pipefail

ARGOCD_NAMESPACE="argocd"
GITOPS_RAW="https://raw.githubusercontent.com/shubhamsingh74888/wanderlust-gitops/main/argocd"
GITOPS_LOCAL="${HOME}/wanderlust-gitops/argocd"   # ← local fallback if raw URL is slow
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

# ── Step 2: Apply ArgoCD Application manifests ─────────────
# Try local copy first (faster, no network dependency),
# fall back to raw GitHub URL if local doesn't exist.
echo ""
echo "[BOOTSTRAP] Applying ArgoCD Application manifests..."

apply_manifest() {
  local name="$1"
  local local_path="${GITOPS_LOCAL}/${name}"
  local remote_url="${GITOPS_RAW}/${name}"

  if [ -f "$local_path" ]; then
    echo "[BOOTSTRAP] Applying ${name} from local copy..."
    kubectl apply -f "$local_path" && \
      echo "[BOOTSTRAP] ✔ ${name} applied (local)" || \
      { echo "[BOOTSTRAP] ✘ Failed to apply ${name}"; return 1; }
  else
    echo "[BOOTSTRAP] Local copy not found — fetching ${name} from GitHub..."
    # Retry up to 3 times with 5s delay
    for attempt in 1 2 3; do
      if kubectl apply -f "$remote_url"; then
        echo "[BOOTSTRAP] ✔ ${name} applied (remote, attempt ${attempt})"
        return 0
      fi
      echo "[BOOTSTRAP] Attempt ${attempt} failed. Retrying in 5s..."
      sleep 5
    done
    echo "[BOOTSTRAP] ✘ Failed to apply ${name} after 3 attempts"
    return 1
  fi
}

apply_manifest "wanderlust-app.yaml"
apply_manifest "prometheus.yaml"

echo "[BOOTSTRAP] ✔ All ArgoCD manifests applied."

# ── Step 3: Verify Application objects were registered ─────
echo ""
echo "[BOOTSTRAP] Verifying ArgoCD Application registration..."
WAIT=0
until kubectl get application wanderlust -n "$ARGOCD_NAMESPACE" > /dev/null 2>&1; do
  if [ $WAIT -ge 60 ]; then
    echo "[BOOTSTRAP] ✘ wanderlust Application not found after 60s — check ArgoCD logs"
    kubectl get pods -n "$ARGOCD_NAMESPACE" || true
    exit 1
  fi
  echo "[BOOTSTRAP] Waiting for Application object... (${WAIT}s)"
  sleep 5
  WAIT=$((WAIT + 5))
done
echo "[BOOTSTRAP] ✔ wanderlust Application registered."

# ── Step 4: Check EBS CSI driver ───────────────────────────
echo ""
echo "[BOOTSTRAP] Checking EBS CSI driver..."
EBS_SA=$(kubectl get serviceaccount ebs-csi-controller-sa \
  -n kube-system \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' \
  2>/dev/null || echo "")

if [ -z "$EBS_SA" ]; then
  echo "[BOOTSTRAP] ⚠ EBS CSI annotation not found — PVCs may not provision."
else
  echo "[BOOTSTRAP] ✔ EBS CSI annotated: $EBS_SA"
fi

# ── Step 5: Final status ────────────────────────────────────
echo ""
echo "[BOOTSTRAP] ── Nodes ─────────────────────────────────"
kubectl get nodes 2>/dev/null || true
echo ""
echo "[BOOTSTRAP] ── ArgoCD Applications ───────────────────"
kubectl get applications -n "$ARGOCD_NAMESPACE" 2>/dev/null || true
echo ""
echo "[BOOTSTRAP] ── Monitoring namespace ──────────────────"
kubectl get pods -n monitoring 2>/dev/null || echo "[BOOTSTRAP] monitoring namespace not yet created."
echo ""
echo "[BOOTSTRAP] ✅ Bootstrap complete."
echo "[BOOTSTRAP]    Monitor sync: kubectl get applications -n argocd -w"
echo "======================================================"
