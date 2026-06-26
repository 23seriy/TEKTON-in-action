#!/usr/bin/env bash
# =============================================================================
# 03 — Build & Deploy the Demo Application + Tekton Resources
# =============================================================================
# Builds the Scores API image inside Minikube, deploys it, and installs
# all Tekton Tasks, Pipelines, and Trigger resources.
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

PROFILE="tekton-demo"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "================================================"
echo "  Tekton in Action — Build & Deploy"
echo "================================================"
echo ""

# ---- Verify kubectl context --------------------------------------------------

CURRENT_CTX=$(kubectl config current-context 2>/dev/null || true)
if [[ "$CURRENT_CTX" != "$PROFILE" ]]; then
    warn "kubectl context is '$CURRENT_CTX', expected '$PROFILE'."
    warn "Switching context..."
    kubectl config use-context "$PROFILE" || { echo "❌ Failed to switch context. Run 02-start-cluster.sh first."; exit 1; }
fi

# ---- Build Images Inside Minikube -------------------------------------------

eval $(minikube docker-env -p "$PROFILE")

info "Building scores-api v1..."
docker build -t scores-api:v1 --build-arg APP_VERSION=v1 "$PROJECT_DIR/apps/scores-api"

info "Building scores-api v2 (with play-by-play)..."
docker build -t scores-api:v2 --build-arg APP_VERSION=v2 "$PROJECT_DIR/apps/scores-api"

eval $(minikube docker-env -p "$PROFILE" --unset)

# ---- Create Namespace --------------------------------------------------------

info "Creating namespace..."
kubectl apply -f "$PROJECT_DIR/k8s/namespace.yaml"

# ---- Deploy RBAC for Tekton --------------------------------------------------

info "Applying Tekton RBAC (ServiceAccount + Role + RoleBinding)..."
kubectl apply -f "$PROJECT_DIR/k8s/tekton-rbac.yaml"

# ---- Deploy Application (initial v1) ----------------------------------------

info "Deploying scores-api (v1)..."
kubectl apply -f "$PROJECT_DIR/k8s/scores-api-deployment.yaml"
kubectl apply -f "$PROJECT_DIR/k8s/scores-api-service.yaml"

# ---- Install Tekton Tasks ----------------------------------------------------

info "Installing Tekton Tasks..."
kubectl apply -f "$PROJECT_DIR/tekton/tasks/git-clone.yaml"
kubectl apply -f "$PROJECT_DIR/tekton/tasks/lint-code.yaml"
kubectl apply -f "$PROJECT_DIR/tekton/tasks/build-image.yaml"
kubectl apply -f "$PROJECT_DIR/tekton/tasks/deploy-app.yaml"
kubectl apply -f "$PROJECT_DIR/tekton/tasks/run-tests.yaml"

# ---- Install Tekton Pipelines ------------------------------------------------

info "Installing Tekton Pipelines..."
kubectl apply -f "$PROJECT_DIR/tekton/pipelines/build-test-deploy.yaml"
kubectl apply -f "$PROJECT_DIR/tekton/pipelines/build-only.yaml"

# ---- Install Tekton Triggers -------------------------------------------------

info "Installing Tekton Triggers..."
kubectl apply -f "$PROJECT_DIR/tekton/triggers/trigger-binding.yaml"
kubectl apply -f "$PROJECT_DIR/tekton/triggers/trigger-template.yaml"
kubectl apply -f "$PROJECT_DIR/tekton/triggers/event-listener.yaml"

# ---- Wait for deployments ---------------------------------------------------

info "Waiting for scores-api to be ready..."
kubectl wait --for=condition=available deployment/scores-api \
    -n tekton-demo --timeout=60s

echo ""
info "✅ All applications and Tekton resources deployed."
echo ""
echo "  Demo pods:"
kubectl get pods -n tekton-demo
echo ""
echo "  Tekton Tasks:"
tkn task list -n tekton-demo 2>/dev/null || kubectl get tasks -n tekton-demo
echo ""
echo "  Tekton Pipelines:"
tkn pipeline list -n tekton-demo 2>/dev/null || kubectl get pipelines -n tekton-demo
echo ""
echo "Access the app:"
echo "  kubectl port-forward svc/scores-api 9080:8080 -n tekton-demo"
echo "  Open http://localhost:9080"
echo ""
echo "Access the Tekton Dashboard:"
echo "  kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines"
echo "  Open http://localhost:9097"
echo ""
echo "Next step:"
echo "  ./scripts/04-demo-scenarios.sh"
echo ""
