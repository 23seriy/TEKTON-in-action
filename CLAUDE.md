# Tekton in Action — Developer Guide

## Project Overview

A hands-on Kubernetes CI/CD demo using Tekton Pipelines. NBA-themed: the Scores API is the service we build, test, and deploy through Tekton Tasks and Pipelines.

## Architecture

- **scores-api** — Flask app with two versions: v1 (basic box scores) and v2 (box scores + play-by-play).
- **Tekton Pipelines** — Installed in `tekton-pipelines` namespace. Provides Tasks, Pipelines, PipelineRuns.
- **Tekton Triggers** — EventListeners that create PipelineRuns from GitHub webhooks.
- **Tekton Dashboard** — Web UI for viewing pipeline runs, task logs, and resource status.
- **Kaniko** — Builds container images inside the cluster (no Docker daemon needed).

## File Structure

```
tekton-in-action/
├── apps/
│   └── scores-api/          # NBA Scores API (Flask, v1 and v2)
├── k8s/                     # Kubernetes manifests (namespace, deployment, service, RBAC)
├── tekton/
│   ├── tasks/               # Reusable Tekton Tasks (git-clone, lint, build, deploy, test)
│   ├── pipelines/           # Pipeline definitions (build-test-deploy, build-only)
│   ├── runs/                # PipelineRun and TaskRun manifests
│   └── triggers/            # EventListener, TriggerBinding, TriggerTemplate
├── scripts/                 # Numbered automation scripts
└── README.md
```

## Common Tasks

### Run the demo
```bash
chmod +x scripts/*.sh
./scripts/01-install-prerequisites.sh
./scripts/02-start-cluster.sh
./scripts/03-deploy-app.sh
./scripts/04-demo-scenarios.sh
```

### Access the app
```bash
kubectl port-forward svc/scores-api 9080:8080 -n tekton-demo
```

### Access the Tekton Dashboard
```bash
kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines
# Open http://localhost:9097
```

### Run a pipeline manually
```bash
kubectl create -f tekton/runs/run-build-test-deploy-v1.yaml
tkn pipelinerun logs -f -n tekton-demo
```

### Run smoke tests only
```bash
kubectl create -f tekton/runs/run-individual-task.yaml
tkn taskrun logs -f -n tekton-demo
```

### Switch between v1 and v2 manually
```bash
kubectl set image deployment/scores-api scores-api=scores-api:v2 -n tekton-demo
kubectl set env deployment/scores-api APP_VERSION=v2 -n tekton-demo
```

### Clean up
```bash
./scripts/05-teardown.sh
```

## Key Design Decisions

1. **Kaniko for image builds** — No Docker-in-Docker or privileged containers needed.
2. **Two pipelines** — `build-test-deploy` for main branch, `build-only` for PRs.
3. **Tekton Triggers** — Demonstrates webhook-driven pipelines (GitHub push events).
4. **Workspaces** — PVCs share source code between pipeline tasks.
5. **NBA theme consistency** — Same pattern as other *-in-action projects.
6. **tkn CLI + Dashboard** — Both CLI and UI approaches shown in the demo.
7. **ServiceAccount RBAC** — Tekton pipelines run with least-privilege permissions.

## LLM Coding Guidelines (Karpathy-Inspired)

### 1. Think Before Coding
Don't assume. Don't hide confusion. Surface tradeoffs.

### 2. Simplicity First
Minimum code that solves the problem. Nothing speculative.

### 3. Surgical Changes
Touch only what you must. Clean up only your own mess.

### 4. Goal-Driven Execution
Define success criteria. Loop until verified.
