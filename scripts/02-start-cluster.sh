#!/usr/bin/env bash
# =============================================================================
# 02 — Start Cluster + Install Tekton
# =============================================================================
# Creates a Minikube profile 'tekton-demo', installs Tekton Pipelines,
# Tekton Triggers, and the Tekton Dashboard.
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR]${NC}   $*"; }

PROFILE="tekton-demo"
K8S_VERSION="v1.32.0"
CPUS=4
MEMORY=6144

# Tekton release versions (use infra.tekton.dev — gcr.io is deprecated)
TEKTON_PIPELINE_VERSION="v0.65.2"
TEKTON_TRIGGERS_VERSION="v0.36.0"
TEKTON_DASHBOARD_VERSION="v0.69.0"
TEKTON_BASE_URL="https://infra.tekton.dev/tekton-releases"

echo ""
echo "================================================"
echo "  Tekton in Action — Start Cluster"
echo "================================================"
echo ""

# ---- Minikube Cluster -------------------------------------------------------

if minikube status -p "$PROFILE" &>/dev/null; then
    info "Minikube profile '$PROFILE' already exists and is running."
else
    info "Creating Minikube profile '$PROFILE' (K8s $K8S_VERSION, ${CPUS} CPUs, ${MEMORY}MB RAM)..."
    minikube start \
        -p "$PROFILE" \
        --kubernetes-version="$K8S_VERSION" \
        --cpus="$CPUS" \
        --memory="$MEMORY" \
        --driver=docker
fi

info "Setting kubectl context to '$PROFILE'..."
kubectl config use-context "$PROFILE"

# ---- Tekton Pipelines -------------------------------------------------------

if kubectl get namespace tekton-pipelines &>/dev/null; then
    info "Tekton Pipelines namespace already exists — checking installation..."
    if kubectl get deployment tekton-pipelines-controller -n tekton-pipelines &>/dev/null; then
        info "Tekton Pipelines is already installed."
    else
        info "Installing Tekton Pipelines $TEKTON_PIPELINE_VERSION..."
        kubectl apply --filename "${TEKTON_BASE_URL}/pipeline/previous/${TEKTON_PIPELINE_VERSION}/release.yaml"
    fi
else
    info "Installing Tekton Pipelines $TEKTON_PIPELINE_VERSION..."
    kubectl apply --filename "${TEKTON_BASE_URL}/pipeline/previous/${TEKTON_PIPELINE_VERSION}/release.yaml"
fi

info "Waiting for Tekton Pipelines to be ready..."
kubectl wait --for=condition=available deployment/tekton-pipelines-controller \
    -n tekton-pipelines --timeout=120s
kubectl wait --for=condition=available deployment/tekton-pipelines-webhook \
    -n tekton-pipelines --timeout=120s

# ---- Tekton Triggers ---------------------------------------------------------

if kubectl get deployment tekton-triggers-controller -n tekton-pipelines &>/dev/null; then
    info "Tekton Triggers is already installed."
else
    info "Installing Tekton Triggers $TEKTON_TRIGGERS_VERSION..."
    kubectl apply --filename "${TEKTON_BASE_URL}/triggers/previous/${TEKTON_TRIGGERS_VERSION}/release.yaml"
    kubectl apply --filename "${TEKTON_BASE_URL}/triggers/previous/${TEKTON_TRIGGERS_VERSION}/interceptors.yaml"
fi

info "Waiting for Tekton Triggers to be ready..."
kubectl wait --for=condition=available deployment/tekton-triggers-controller \
    -n tekton-pipelines --timeout=120s 2>/dev/null || warn "Triggers controller still starting..."

# ---- Tekton Dashboard --------------------------------------------------------

if kubectl get deployment tekton-dashboard -n tekton-pipelines &>/dev/null; then
    info "Tekton Dashboard is already installed."
else
    info "Installing Tekton Dashboard $TEKTON_DASHBOARD_VERSION..."
    kubectl apply --filename "${TEKTON_BASE_URL}/dashboard/previous/${TEKTON_DASHBOARD_VERSION}/release.yaml"
fi

info "Waiting for Tekton Dashboard to be ready..."
kubectl wait --for=condition=available deployment/tekton-dashboard \
    -n tekton-pipelines --timeout=120s 2>/dev/null || warn "Dashboard still starting..."

# ---- Summary -----------------------------------------------------------------

echo ""
info "✅ Cluster is ready. Tekton Pipelines + Triggers + Dashboard installed."
echo ""
echo "  Tekton pods:"
kubectl get pods -n tekton-pipelines
echo ""
echo "  Access Dashboard:"
echo "    kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines"
echo "    Open http://localhost:9097"
echo ""
echo "Next step:"
echo "  ./scripts/03-deploy-app.sh"
echo ""
