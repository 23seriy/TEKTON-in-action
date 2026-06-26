#!/usr/bin/env bash
# =============================================================================
# 05 — Teardown
# =============================================================================
# Deletes all demo resources, uninstalls Tekton components,
# and removes the Minikube cluster.
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

PROFILE="tekton-demo"
TEKTON_BASE_URL="https://infra.tekton.dev/tekton-releases"

echo ""
echo "================================================"
echo "  Tekton in Action — Teardown"
echo "================================================"
echo ""

# ---- Confirmation prompt -----------------------------------------------------

echo "⚠️  This will:"
echo "   • Delete the tekton-demo namespace and all demo pods"
echo "   • Uninstall Tekton Pipelines, Triggers, and Dashboard"
echo "   • Delete the '$PROFILE' Minikube cluster entirely"
echo ""
read -r -p "Are you sure? (y/N) " confirm
case "$confirm" in
    [yY][eE][sS]|[yY]) ;;
    *)
        info "Teardown cancelled."
        exit 0
        ;;
esac

echo ""

# ---- Delete demo namespace ---------------------------------------------------

info "Deleting demo namespace..."
kubectl delete namespace tekton-demo --ignore-not-found --timeout=30s 2>/dev/null || true

# ---- Uninstall Tekton Dashboard -----------------------------------------------

info "Uninstalling Tekton Dashboard..."
kubectl delete --filename "${TEKTON_BASE_URL}/dashboard/previous/v0.69.0/release.yaml" 2>/dev/null || true

# ---- Uninstall Tekton Triggers ------------------------------------------------

info "Uninstalling Tekton Triggers..."
kubectl delete --filename "${TEKTON_BASE_URL}/triggers/previous/v0.36.0/interceptors.yaml" 2>/dev/null || true
kubectl delete --filename "${TEKTON_BASE_URL}/triggers/previous/v0.36.0/release.yaml" 2>/dev/null || true

# ---- Uninstall Tekton Pipelines -----------------------------------------------

info "Uninstalling Tekton Pipelines..."
kubectl delete --filename "${TEKTON_BASE_URL}/pipeline/previous/v0.65.2/release.yaml" 2>/dev/null || true

# ---- Delete Minikube cluster -------------------------------------------------

info "Deleting Minikube profile '$PROFILE'..."
minikube delete -p "$PROFILE" 2>/dev/null || true

echo ""
info "✅ Teardown complete. Cluster and all resources removed."
echo ""
