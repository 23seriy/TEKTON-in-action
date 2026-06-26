#!/usr/bin/env bash
# =============================================================================
# 04 — Demo Scenarios
# =============================================================================
# Interactive walkthrough of Tekton features: Tasks, Pipelines, PipelineRuns,
# Triggers, and the Dashboard.
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
step()  { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

pause() {
    echo ""
    read -r -p "Press ENTER to continue to the next scenario... "
    echo ""
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "================================================"
echo "  Tekton in Action — Demo Scenarios"
echo "================================================"
echo ""
echo "This script walks you through 7 scenarios demonstrating"
echo "Tekton Pipelines, Tasks, Triggers, and the Dashboard."
echo ""
echo "Prerequisites:"
echo "  ✅ Cluster running (02-start-cluster.sh)"
echo "  ✅ App deployed (03-deploy-app.sh)"
echo ""
echo "Recommended: Open the Tekton Dashboard in another terminal:"
echo "  kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines"
echo "  http://localhost:9097"
echo ""
pause

# ==============================================================================
# Scenario 1: Explore Tekton Resources
# ==============================================================================
step "Scenario 1: Explore Tekton Resources"

echo "Let's see what Tekton resources are installed in the cluster."
echo ""

info "Tasks (reusable build steps):"
tkn task list -n tekton-demo 2>/dev/null || kubectl get tasks -n tekton-demo
echo ""

info "Pipelines (ordered task sequences):"
tkn pipeline list -n tekton-demo 2>/dev/null || kubectl get pipelines -n tekton-demo
echo ""

info "EventListeners (webhook receivers):"
kubectl get eventlisteners -n tekton-demo 2>/dev/null || echo "  (none yet)"
echo ""

info "TriggerTemplates:"
kubectl get triggertemplates -n tekton-demo 2>/dev/null || echo "  (none yet)"
echo ""

echo "💡 Tasks are like functions. Pipelines chain them. Triggers invoke pipelines"
echo "   automatically when events (webhooks, git pushes) arrive."

pause

# ==============================================================================
# Scenario 2: Run a Single Task — Smoke Tests
# ==============================================================================
step "Scenario 2: Run a Single Task — Smoke Tests"

echo "Before running a full pipeline, let's run a single Task directly."
echo "This runs the 'run-tests' task against the already-deployed Scores API."
echo ""

info "Creating a TaskRun..."
kubectl create -f "$PROJECT_DIR/tekton/runs/run-individual-task.yaml"

echo ""
info "Watching TaskRun progress..."
sleep 3

LATEST_TR=$(tkn taskrun list -n tekton-demo --no-headers 2>/dev/null | head -1 | awk '{print $1}')
if [[ -n "$LATEST_TR" ]]; then
    tkn taskrun logs "$LATEST_TR" -n tekton-demo -f 2>/dev/null || \
        kubectl logs --selector=tekton.dev/taskRun="$LATEST_TR" -n tekton-demo --all-containers --tail=50
else
    warn "Could not find TaskRun — check the dashboard."
fi

echo ""
info "TaskRun status:"
tkn taskrun list -n tekton-demo 2>/dev/null || kubectl get taskruns -n tekton-demo

pause

# ==============================================================================
# Scenario 3: Run the Full Pipeline — Build, Test, Deploy v1
# ==============================================================================
step "Scenario 3: Full Pipeline — Build → Lint → Build Image → Deploy → Test"

echo "Now let's run the full build-test-deploy pipeline."
echo "This clones the repo, lints the code, builds a container image,"
echo "deploys it, and runs smoke tests — all as Kubernetes pods."
echo ""
echo "⚠️  This requires internet access to clone the git repo."
echo "    If the cluster can't reach GitHub, the clone step will fail."
echo "    That's expected in air-gapped environments — skip to scenario 5."
echo ""

info "Creating PipelineRun for v1..."
kubectl create -f "$PROJECT_DIR/tekton/runs/run-build-test-deploy-v1.yaml"

echo ""
info "Watching PipelineRun progress..."
sleep 3

LATEST_PR=$(tkn pipelinerun list -n tekton-demo --no-headers 2>/dev/null | head -1 | awk '{print $1}')
if [[ -n "$LATEST_PR" ]]; then
    echo "  PipelineRun: $LATEST_PR"
    echo "  View in dashboard: http://localhost:9097/#/namespaces/tekton-demo/pipelineruns/$LATEST_PR"
    echo ""
    echo "  To watch logs:"
    echo "    tkn pipelinerun logs $LATEST_PR -n tekton-demo -f"
else
    warn "Could not find PipelineRun — check the Tekton Dashboard."
fi

echo ""
info "PipelineRun status:"
tkn pipelinerun list -n tekton-demo 2>/dev/null || kubectl get pipelineruns -n tekton-demo

pause

# ==============================================================================
# Scenario 4: Deploy v2 — The New Feature Release
# ==============================================================================
step "Scenario 4: Deploy v2 — Ship Play-by-Play Data"

echo "Time to ship v2! This pipeline builds the Scores API with play-by-play"
echo "data enabled (APP_VERSION=v2) and deploys it."
echo ""

info "Creating PipelineRun for v2..."
kubectl create -f "$PROJECT_DIR/tekton/runs/run-build-test-deploy-v2.yaml"

echo ""
LATEST_PR=$(tkn pipelinerun list -n tekton-demo --no-headers 2>/dev/null | head -1 | awk '{print $1}')
if [[ -n "$LATEST_PR" ]]; then
    echo "  PipelineRun: $LATEST_PR"
    echo "  View in dashboard: http://localhost:9097/#/namespaces/tekton-demo/pipelineruns/$LATEST_PR"
    echo ""
    echo "  To watch logs:"
    echo "    tkn pipelinerun logs $LATEST_PR -n tekton-demo -f"
fi

echo ""
echo "💡 After v2 deploys, visit http://localhost:9080 — you'll see"
echo "   play-by-play data under each game card."

pause

# ==============================================================================
# Scenario 5: Manual Deploy — Quick Local Build
# ==============================================================================
step "Scenario 5: Manual Deploy (No Pipeline)"

echo "Sometimes you just want to deploy without a full pipeline run."
echo "This uses the pre-built images from step 03 and kubectl directly."
echo ""

info "Switching to v1 (basic scores)..."
kubectl set image deployment/scores-api scores-api=scores-api:v1 -n tekton-demo
kubectl set env deployment/scores-api APP_VERSION=v1 BUILD_ID=manual-v1 -n tekton-demo
kubectl rollout status deployment/scores-api -n tekton-demo --timeout=60s
echo ""
info "✅ Deployed v1. Visit http://localhost:9080"
echo ""

read -r -p "Press ENTER to switch to v2..."
echo ""

info "Switching to v2 (play-by-play)..."
kubectl set image deployment/scores-api scores-api=scores-api:v2 -n tekton-demo
kubectl set env deployment/scores-api APP_VERSION=v2 BUILD_ID=manual-v2 -n tekton-demo
kubectl rollout status deployment/scores-api -n tekton-demo --timeout=60s
echo ""
info "✅ Deployed v2. Visit http://localhost:9080 — play-by-play is now live."

pause

# ==============================================================================
# Scenario 6: Build-Only Pipeline — PR Validation
# ==============================================================================
step "Scenario 6: Build-Only Pipeline — PR Validation"

echo "Not every pipeline run should deploy. The 'build-only' pipeline"
echo "clones, lints, and builds — but skips deployment. Perfect for PRs."
echo ""

info "Creating build-only PipelineRun..."
kubectl create -f "$PROJECT_DIR/tekton/runs/run-build-only.yaml"

echo ""
LATEST_PR=$(tkn pipelinerun list -n tekton-demo --no-headers 2>/dev/null | head -1 | awk '{print $1}')
if [[ -n "$LATEST_PR" ]]; then
    echo "  PipelineRun: $LATEST_PR"
    echo "  View in dashboard: http://localhost:9097/#/namespaces/tekton-demo/pipelineruns/$LATEST_PR"
fi

echo ""
echo "💡 In production, you'd wire the build-only pipeline to PR events"
echo "   and the build-test-deploy pipeline to main branch pushes."

pause

# ==============================================================================
# Scenario 7: Explore the Tekton Dashboard
# ==============================================================================
step "Scenario 7: Explore the Tekton Dashboard"

echo "The Tekton Dashboard gives you a visual view of everything:"
echo ""
echo "  📋 PipelineRuns — see all pipeline executions and their status"
echo "  🔧 TaskRuns     — drill into individual task step logs"
echo "  📦 Tasks        — browse reusable task definitions"
echo "  🔗 Pipelines    — see how tasks are chained together"
echo "  🎯 Triggers     — view EventListeners and TriggerTemplates"
echo ""
echo "Open the dashboard:"
echo "  kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines"
echo "  http://localhost:9097"
echo ""

info "Current PipelineRun history:"
tkn pipelinerun list -n tekton-demo 2>/dev/null || kubectl get pipelineruns -n tekton-demo
echo ""

info "Current TaskRun history:"
tkn taskrun list -n tekton-demo 2>/dev/null || kubectl get taskruns -n tekton-demo

echo ""
echo "================================================"
echo "  🎉 Demo Complete!"
echo "================================================"
echo ""
echo "What you learned:"
echo "  1. Tasks      — Reusable build steps (lint, build, test, deploy)"
echo "  2. Pipelines  — Chain tasks into CI/CD workflows"
echo "  3. PipelineRuns — Execute pipelines with specific parameters"
echo "  4. Triggers   — Auto-start pipelines from webhooks"
echo "  5. Dashboard  — Visual management of all Tekton resources"
echo "  6. Workspaces — Share data between pipeline tasks"
echo "  7. Build-only — Separate pipelines for PRs vs deploys"
echo ""
echo "Teardown: ./scripts/05-teardown.sh"
echo ""
