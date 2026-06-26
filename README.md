# 🔧 Tekton in Action

A hands-on project demonstrating **Tekton Pipelines** — cloud-native CI/CD built as Kubernetes CRDs. Instead of running Jenkins on a VM or configuring GitHub Actions YAML, you define your entire build pipeline as Kubernetes resources: Tasks, Pipelines, and Triggers — all running inside your cluster.

The demo uses a simple NBA Scores API to showcase how Tekton builds, tests, and deploys applications. You'll create reusable Tasks, chain them into Pipelines, trigger builds from webhooks, and watch everything in the Tekton Dashboard — all on your laptop.

![Tekton](https://img.shields.io/badge/Tekton-0.65+Triggers_0.36-FD495C?logo=tekton&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32-326CE5?logo=kubernetes&logoColor=white)
![Minikube](https://img.shields.io/badge/Minikube-local-F7B93E?logo=kubernetes&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)

> 📝 **Read the full walkthrough on Medium:** *(link to be added after publishing)*

## 📖 Documentation

- **[CLAUDE.md](CLAUDE.md)** — Architecture, file structure, and conventions for AI-assisted development

## 🏗️ Architecture

```text
                 ┌──────────────────────────────────────────────────┐
                 │                 Minikube Cluster                  │
                 │                                                  │
 User ────────►  │  Scores API (v1 or v2)                           │
 localhost:9080 │  deployed by Tekton Pipeline                     │
                 │                                                  │
                 │  ┌──────────────────────────────────────────┐   │
                 │  │         Tekton Pipeline                   │   │
                 │  │                                           │   │
                 │  │  git-clone → lint → build → deploy → test │   │
                 │  │                                           │   │
                 │  │  📦 Kaniko builds images (no Docker daemon)│   │
                 │  │  🧪 Smoke tests verify deployment         │   │
                 │  │  📋 Dashboard shows pipeline progress     │   │
                 │  └──────────────────────────────────────────┘   │
                 │                                                  │
                 │  ┌──────────────────────────────────────────┐   │
                 │  │         Tekton Triggers                   │   │
                 │  │                                           │   │
                 │  │  EventListener ◄──── GitHub Webhook       │   │
                 │  │       │                                   │   │
                 │  │       ▼                                   │   │
                 │  │  TriggerBinding → TriggerTemplate          │   │
                 │  │       │                                   │   │
                 │  │       ▼                                   │   │
                 │  │  Auto-creates PipelineRun                 │   │
                 │  └──────────────────────────────────────────┘   │
                 │                                                  │
                 │  Tekton Dashboard ──► http://localhost:9097      │
                 └──────────────────────────────────────────────────┘
```

**Scores API v1** — Returns basic NBA box scores (team, score, quarter, arena). The initial build.

**Scores API v2** — Same box scores **plus live play-by-play** data. The new version shipped through the pipeline.

**Tekton Pipeline** — Five tasks chained together: clone → lint → build (Kaniko) → deploy → test.

**Tekton Triggers** — EventListener receives GitHub push webhooks and auto-creates PipelineRuns.

**Tekton Dashboard** — Web UI for viewing pipeline runs, task logs, and Tekton resources.

## 📋 What You'll Learn

| Tekton Concept | What It Does | Demo Scenario |
|---|---|---|
| **Tasks** | Reusable build steps (containers that run scripts) | git-clone, lint, build-image, deploy, run-tests |
| **Pipelines** | Chain tasks into CI/CD workflows with dependencies | build-test-deploy (5 steps), build-only (3 steps) |
| **PipelineRuns** | Execute a pipeline with specific parameters | Build v1, build v2, PR validation |
| **TaskRuns** | Execute a single task directly | Run smoke tests independently |
| **Workspaces** | Share data (source code, artifacts) between tasks | PVC-backed workspace for source and build context |
| **Kaniko** | Build container images without Docker daemon | Build Scores API inside the cluster |
| **Triggers** | Auto-start pipelines from external events | GitHub push → PipelineRun |
| **Dashboard** | Visual management of all Tekton resources | Browse runs, view logs, inspect tasks |

## 🚀 Quick Start

### Step 0: Clone the Repository

```bash
git clone https://github.com/23seriy/tekton-in-action.git
cd tekton-in-action
```

### Prerequisites

- **macOS** (scripts use Homebrew; adapt for Linux)
- **Docker Desktop** running
- ~6 GB RAM available for Minikube

### Step 1: Install Tools

```bash
chmod +x scripts/*.sh
./scripts/01-install-prerequisites.sh
```

This installs `minikube`, `kubectl`, `helm`, `docker`, and `tkn` (Tekton CLI) via Homebrew.

### Step 2: Start Cluster + Install Tekton

```bash
./scripts/02-start-cluster.sh
```

Creates the `tekton-demo` Minikube profile on **Kubernetes v1.32.0**, then installs Tekton Pipelines, Tekton Triggers, and the Tekton Dashboard.

### Step 3: Build & Deploy

```bash
./scripts/03-deploy-app.sh
```

Builds v1 and v2 container images inside Minikube, deploys the Scores API (v1), and installs all Tekton Tasks, Pipelines, and Triggers.

### Step 4: Access the Application

The Scores API and Tekton Dashboard run inside the Minikube cluster. To access them from your browser, start port-forwards in **separate terminals**:

```bash
# Terminal 1: Scores API
kubectl port-forward svc/scores-api 9080:8080 -n tekton-demo

# Terminal 2: Tekton Dashboard
kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines
```

Then open:
- **http://localhost:9080** — NBA Scores API (v1: basic scores, v2: with play-by-play)
- **http://localhost:9097** — Tekton Dashboard (pipeline runs, task logs, triggers)

Alternatively, use Minikube's built-in service tunnel:

```bash
minikube service scores-api -n tekton-demo -p tekton-demo
```

> **Note:** Keep the port-forward terminals running throughout the demo. The demo script references `http://localhost:9080` — it won't be reachable without the port-forward.

### Step 5: Run the Demo Scenarios

```bash
./scripts/04-demo-scenarios.sh
```

This walks you through 7 interactive scenarios.

## 🎮 Demo Scenarios

### 1. Explore Tekton Resources

```bash
tkn task list -n tekton-demo
tkn pipeline list -n tekton-demo
kubectl get eventlisteners -n tekton-demo
```

See all installed Tasks, Pipelines, and Triggers. Tasks are like functions, Pipelines chain them, Triggers invoke pipelines from events.

### 2. Run a Single Task — Smoke Tests

```bash
kubectl create -f tekton/runs/run-individual-task.yaml
tkn taskrun logs -f -n tekton-demo
```

Run the `run-tests` task directly against the deployed Scores API. Tests `/health`, `/scores`, `/build-info`, and `/test` endpoints.

### 3. Full Pipeline — Build → Test → Deploy v1

```bash
kubectl create -f tekton/runs/run-build-test-deploy-v1.yaml
tkn pipelinerun logs -f -n tekton-demo
```

The full CI/CD pipeline: clone the repo, lint the Python code, build a container with Kaniko, deploy to the cluster, and run smoke tests.

### 4. Deploy v2 — Ship Play-by-Play Data

```bash
kubectl create -f tekton/runs/run-build-test-deploy-v2.yaml
tkn pipelinerun logs -f -n tekton-demo
```

Same pipeline, different parameters. Builds v2 with `APP_VERSION=v2` and deploys it. Visit **http://localhost:9080** to see play-by-play data under each game card (requires port-forward — see [Step 4](#step-4-access-the-application)).

### 5. Manual Deploy — Quick Switch

```bash
# Switch to v1
kubectl set image deployment/scores-api scores-api=scores-api:v1 -n tekton-demo
kubectl set env deployment/scores-api APP_VERSION=v1 -n tekton-demo

# Switch to v2
kubectl set image deployment/scores-api scores-api=scores-api:v2 -n tekton-demo
kubectl set env deployment/scores-api APP_VERSION=v2 -n tekton-demo
```

Sometimes you just want to deploy without a full pipeline run. Verify each switch at **http://localhost:9080** (requires port-forward — see [Step 4](#step-4-access-the-application)).

### 6. Build-Only Pipeline — PR Validation

```bash
kubectl create -f tekton/runs/run-build-only.yaml
tkn pipelinerun logs -f -n tekton-demo
```

The `build-only` pipeline clones, lints, and builds — but **doesn't deploy**. Perfect for validating pull requests.

### 7. Explore the Tekton Dashboard

```bash
kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines
# Open http://localhost:9097
```

Visual view of PipelineRuns, TaskRuns, Tasks, Pipelines, and Triggers. Drill into logs for each pipeline step.

## 🔧 Useful Commands

```bash
# Tekton CLI — list resources
tkn task list -n tekton-demo
tkn pipeline list -n tekton-demo
tkn pipelinerun list -n tekton-demo
tkn taskrun list -n tekton-demo

# Watch pipeline run logs
tkn pipelinerun logs -f -n tekton-demo

# Describe a pipeline
tkn pipeline describe build-test-deploy -n tekton-demo

# Cancel a running pipeline
tkn pipelinerun cancel <name> -n tekton-demo

# Delete completed runs
tkn pipelinerun delete --all -n tekton-demo

# App access
kubectl port-forward svc/scores-api 9080:8080 -n tekton-demo
curl http://localhost:9080/scores
curl http://localhost:9080/health
curl http://localhost:9080/build-info
```

## 📁 Project Structure

```text
tekton-in-action/
├── apps/
│   └── scores-api/                    # NBA Scores API (Flask)
│       ├── app.py                     # Single source, version via APP_VERSION env
│       ├── Dockerfile
│       └── requirements.txt
├── k8s/                               # Kubernetes manifests
│   ├── namespace.yaml                 # tekton-demo
│   ├── scores-api-deployment.yaml     # Deployment (v1 default)
│   ├── scores-api-service.yaml        # ClusterIP Service
│   └── tekton-rbac.yaml              # ServiceAccount + Role + RoleBinding
├── tekton/
│   ├── tasks/                         # Reusable Tekton Tasks
│   │   ├── git-clone.yaml            # Clone a git repo into a workspace
│   │   ├── lint-code.yaml            # Python syntax check + PEP 8
│   │   ├── build-image.yaml          # Build container with Kaniko
│   │   ├── deploy-app.yaml           # kubectl set image + rollout
│   │   └── run-tests.yaml            # Smoke tests (health, scores, build-info)
│   ├── pipelines/                     # Pipeline definitions
│   │   ├── build-test-deploy.yaml    # Full CI/CD: clone → lint → build → deploy → test
│   │   └── build-only.yaml           # PR validation: clone → lint → build
│   ├── runs/                          # PipelineRun / TaskRun manifests
│   │   ├── run-build-test-deploy-v1.yaml
│   │   ├── run-build-test-deploy-v2.yaml
│   │   ├── run-build-only.yaml
│   │   └── run-individual-task.yaml
│   └── triggers/                      # Tekton Triggers
│       ├── event-listener.yaml       # Receives GitHub webhooks
│       ├── trigger-binding.yaml      # Extracts git-url and revision from payload
│       └── trigger-template.yaml     # Creates PipelineRun from trigger
├── scripts/                           # Automation scripts
│   ├── 01-install-prerequisites.sh
│   ├── 02-start-cluster.sh           # Minikube + Tekton Pipelines/Triggers/Dashboard
│   ├── 03-deploy-app.sh              # Build images + deploy app + install Tekton resources
│   ├── 04-demo-scenarios.sh          # 7 interactive demo scenarios
│   └── 05-teardown.sh
├── CLAUDE.md                          # Developer guide
├── LICENSE                            # MIT
└── .gitignore
```

## 🧹 Teardown

```bash
./scripts/05-teardown.sh
```

Deletes all demo resources, uninstalls Tekton Pipelines, Triggers, and Dashboard, and removes the Minikube cluster.

## 💡 Key Takeaways

1. **CI/CD as Kubernetes resources** — Tasks, Pipelines, and Triggers are CRDs. You manage them with `kubectl` and `tkn`, version them in git, and they run as pods. No external CI server needed.

2. **Tasks are reusable building blocks** — Write a task once (lint, build, test), use it in many pipelines. Like functions in code. The Tekton Hub has hundreds of community tasks.

3. **Kaniko eliminates Docker-in-Docker** — Build container images inside the cluster without privileged containers or a Docker daemon. Each build step runs in its own pod.

4. **Triggers close the loop** — EventListeners receive webhooks, TriggerBindings extract data, TriggerTemplates create PipelineRuns. Push to git → pipeline runs automatically.

5. **Workspaces share data between tasks** — PVC-backed workspaces let the clone task write source code that the build task reads. No external artifact storage needed.

6. **Separate pipelines for separate purposes** — `build-test-deploy` for main branch, `build-only` for PRs. Different pipelines for different workflows.

7. **The Dashboard makes it visual** — Real-time pipeline progress, step-by-step logs, resource browsing. Better than watching `kubectl get pods` scroll by.

## 📚 Resources

- [Tekton Documentation](https://tekton.dev/docs/)
- [Tekton Pipelines](https://tekton.dev/docs/pipelines/)
- [Tekton Triggers](https://tekton.dev/docs/triggers/)
- [Tekton Dashboard](https://tekton.dev/docs/dashboard/)
- [Tekton Hub — Community Tasks](https://hub.tekton.dev/)
- [Kaniko — Container Image Builder](https://github.com/GoogleContainerTools/kaniko)
- [tkn CLI Reference](https://tekton.dev/docs/cli/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

## 📝 License

MIT — Use freely for learning, demos, and presentations.
