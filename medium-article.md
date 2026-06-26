# I Replaced Jenkins With 50 Lines of YAML — Here's What Happened

## Tekton Pipelines turned my CI/CD into Kubernetes-native resources. No VMs, no plugins, no Jenkins maintenance weekends.

---

Last month I killed our Jenkins server.

Not metaphorically. I `kubectl delete`-ed it. And I haven't looked back.

The replacement? **Tekton Pipelines** — an open-source, Kubernetes-native CI/CD framework where your entire build pipeline is defined as Kubernetes Custom Resource Definitions. Tasks are pods. Pipelines are YAML. Triggers are webhooks that create PipelineRuns automatically.

No Java. No plugins. No "manage Jenkins" page. Just Kubernetes resources.

I built a complete working demo to prove it works — and I'm open-sourcing everything so you can run it on your laptop in under 10 minutes.

**👉 [GitHub: tekton-in-action](https://github.com/23seriy/TEKTON-in-action)**

---

## The Problem: CI/CD Shouldn't Need Its Own Infrastructure

If you've ever managed Jenkins, you know the pain:

- Plugin compatibility hell after every update
- Groovy scripts that nobody understands 6 months later
- A dedicated VM (or three) just to run builds
- "Works on my Jenkins" as a debugging statement
- Credential management that keeps your security team awake at night

GitHub Actions helped. But it's still a proprietary platform running *outside* your cluster. Your builds happen somewhere else, your secrets live somewhere else, and you're paying per minute for compute you already have.

**What if your CI/CD pipeline was just another Kubernetes workload?**

That's Tekton.

---

## What Tekton Actually Is (In 60 Seconds)

Tekton installs as a set of CRDs (Custom Resource Definitions) in your Kubernetes cluster. You get four key concepts:

| Concept | What It Is | Kubernetes Analogy |
|---------|-----------|-------------------|
| **Task** | A reusable build step (runs as a pod) | Like a Job template |
| **Pipeline** | Ordered chain of Tasks with dependencies | Like a Workflow |
| **PipelineRun** | A specific execution of a Pipeline | Like a Job |
| **Trigger** | Auto-creates PipelineRuns from webhooks | Like an event-driven controller |

That's it. No server to maintain. No UI to configure. Everything is YAML, versioned in git, applied with `kubectl`.

---

## The Demo: NBA Scores API

To make this concrete, I built an NBA Scores API — a Flask app that returns live game data. Two versions:

- **v1** — Basic box scores (teams, scores, quarter, arena)
- **v2** — Same data **plus live play-by-play** (LeBron's driving layup, Curry's logo three)

The pipeline builds, tests, and deploys both versions. You watch it happen in real time.

Here's what the full CI/CD pipeline looks like as a Tekton resource:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: build-test-deploy
spec:
  tasks:
    - name: clone          # Clone the git repo
      taskRef: { name: git-clone }

    - name: lint           # Lint the Python code
      taskRef: { name: lint-code }
      runAfter: [clone]

    - name: build          # Build container with Kaniko (no Docker daemon!)
      taskRef: { name: build-image }
      runAfter: [lint]

    - name: deploy         # kubectl set image + rollout
      taskRef: { name: deploy-app }
      runAfter: [build]

    - name: test           # Smoke tests against live endpoints
      taskRef: { name: run-tests }
      runAfter: [deploy]
```

Five tasks. Five pods. Each one runs, completes, passes data to the next through a shared workspace. The whole thing takes about 90 seconds.

---

## Running It Yourself (10 Minutes, Seriously)

### Prerequisites
- Docker Desktop running
- ~6 GB RAM available
- macOS (scripts use Homebrew — easy to adapt for Linux)

### Four commands:

```bash
git clone https://github.com/23seriy/TEKTON-in-action.git
cd tekton-in-action

# Install tools (minikube, kubectl, tkn CLI)
./scripts/01-install-prerequisites.sh

# Start Minikube + install Tekton Pipelines, Triggers, Dashboard
./scripts/02-start-cluster.sh

# Build the app images + deploy + install all Tekton resources
./scripts/03-deploy-app.sh
```

That's it. You now have:

- A Minikube cluster running Kubernetes 1.32
- Tekton Pipelines v0.65.2 + Triggers v0.36.0 + Dashboard v0.69.0
- 5 reusable Tasks, 2 Pipelines, webhook Triggers
- The NBA Scores API running with 2 replicas

### Access the apps:

```bash
# Terminal 1: NBA Scores API
kubectl port-forward svc/scores-api 9080:8080 -n tekton-demo

# Terminal 2: Tekton Dashboard
kubectl port-forward svc/tekton-dashboard 9097:9097 -n tekton-pipelines
```

Open `http://localhost:9080` — you'll see live NBA scores. Open `http://localhost:9097` — you'll see the Tekton Dashboard.

---

## The 7 Demo Scenarios

The project includes an interactive demo script that walks you through everything:

```bash
./scripts/04-demo-scenarios.sh
```

Each scenario has **built-in verification** — the script checks pod health, validates API responses, confirms correct versions, and reports pass/fail for every step.

### Scenario 1: Explore What's Installed

```
[PASS]  5 tasks installed (expected ≥5)
[PASS]  2 pipelines installed (expected ≥2)
[PASS]  EventListener 'github-listener' is ready
[PASS]  All pods ready (2/2)
```

Five tasks. Two pipelines. One EventListener. All defined as Kubernetes resources. All manageable with `kubectl` and `tkn`.

### Scenario 2: Run a Single Task

Before running a full pipeline, run just the smoke tests:

```bash
kubectl create -f tekton/runs/run-individual-task.yaml
```

```
[test-health]    ✅ Health check passed
[test-scores]    ✅ Scores endpoint passed
[test-build-info] ✅ Build-info endpoint passed
[test-app-tests]  ✅ App self-test passed
                  🎉 All tests PASSED
```

A Task is just a pod with steps. Each step is a container. When it finishes, Kubernetes cleans it up. No build agents hanging around.

### Scenario 3: Full Pipeline — Build v1

Now the real thing:

```bash
kubectl create -f tekton/runs/run-build-test-deploy-v1.yaml
```

Watch five pods spin up in sequence:

1. **git-clone** — Clones the repo into a shared workspace (PVC)
2. **lint-code** — Runs Python syntax checks
3. **build-image** — Kaniko builds a container image *inside* the cluster (no Docker daemon)
4. **deploy-app** — `kubectl set image` + rollout
5. **run-tests** — Hits all endpoints, verifies the deployment

```
[PASS]  PipelineRun succeeded
[PASS]  All pods ready (2/2)
[PASS]  App version is 'v1'
[PASS]  Health endpoint returned 200 OK
```

### Scenario 4: Ship v2 — The Play-by-Play Update

Same pipeline, different parameters:

```bash
kubectl create -f tekton/runs/run-build-test-deploy-v2.yaml
```

This builds with `APP_VERSION=v2`, deploys, and now the API returns play-by-play data — Jokić's no-look passes and Giannis euro-steps included.

```
[PASS]  App version is 'v2'
[PASS]  Health endpoint returned 200 OK
[PASS]  Scores endpoint returned 200 OK
```

**Same pipeline. Different params. Different output.** That's the power of parameterized pipelines.

### Scenario 5: Manual Deploy — Quick Switch

Not everything needs a pipeline. Sometimes you just want to flip between versions:

```bash
kubectl set image deployment/scores-api scores-api=scores-api:v1 -n tekton-demo
kubectl set env deployment/scores-api APP_VERSION=v1 -n tekton-demo
```

The demo script verifies each switch — pods ready, correct version, all endpoints healthy. Both directions. v1 → v2 → v1.

### Scenario 6: Build-Only Pipeline — PR Validation

Not every pipeline should deploy. For pull requests, you want to clone, lint, and build — but **not** deploy:

```yaml
# build-only pipeline: 3 tasks, no deploy, no test
tasks:
  - name: clone → lint → build
```

```
[PASS]  Build-only pipeline completed — no deployment occurred (by design)
[PASS]  App version is 'v2'  # Still v2 from the previous scenario
```

Two pipelines, two purposes: `build-test-deploy` for main branch, `build-only` for PRs.

### Scenario 7: The Dashboard

The Tekton Dashboard at `http://localhost:9097` gives you visual pipeline tracking — click into any PipelineRun, see each task's status, drill into container logs for each step.

```
[PASS]  5 Tasks | 2 Pipelines | 3 PipelineRuns | 12 TaskRuns
[PASS]  All pods ready (2/2)
[PASS]  Health endpoint returned 200 OK
```

---

## The Part Nobody Talks About: Kaniko

Here's the dirty secret of CI/CD in Kubernetes: building Docker images usually requires Docker. And running Docker inside Kubernetes means either Docker-in-Docker (security nightmare) or mounting the Docker socket (even worse).

**Kaniko solves this.** It builds OCI-compliant container images entirely in userspace — no Docker daemon, no privileged containers. It runs as a regular pod.

In the Tekton task:

```yaml
steps:
  - name: build-and-push
    image: gcr.io/kaniko-project/executor:latest
    command: [/kaniko/executor]
    args:
      - "--dockerfile=Dockerfile"
      - "--context=dir://$(workspaces.source.path)/source/apps/scores-api"
      - "--destination=scores-api:v1"
      - "--no-push"
      - "--build-arg=APP_VERSION=v1"
```

Kaniko reads the Dockerfile, builds the image, and either pushes it to a registry or (in our local case) keeps it in the cluster. No special privileges needed.

---

## Triggers: The Webhook Loop

The demo includes a complete Tekton Triggers setup:

```
GitHub push → EventListener → TriggerBinding → TriggerTemplate → PipelineRun
```

An **EventListener** is a Kubernetes Service that receives webhooks. A **TriggerBinding** extracts fields from the webhook payload (repo URL, branch, commit SHA). A **TriggerTemplate** creates a PipelineRun with those values.

Push to `main` → pipeline runs automatically. No GitHub Actions, no external CI. Just Kubernetes resources reacting to HTTP events.

---

## What I Learned Building This

### 1. YAML is actually fine

Everyone complains about YAML. But Tekton's YAML is *structural* — each file represents a real Kubernetes resource. You can `kubectl get`, `kubectl describe`, `kubectl delete` your pipelines. Try that with a Jenkinsfile.

### 2. Debugging is better

When a Jenkins build fails, you SSH into the agent, check logs, maybe restart the service. When a Tekton TaskRun fails, you `kubectl logs` the pod. Same tools you already know. Same namespace as your app.

### 3. RBAC is built in

Tekton uses ServiceAccounts. You control exactly what each pipeline can do — which namespaces it can deploy to, which secrets it can access. Kubernetes RBAC, not a Jenkins credential store.

### 4. Reusability is real

The `build-image` task works for any Dockerfile. The `git-clone` task works for any repo. The `run-tests` task works for any HTTP endpoint. Write once, use across projects. The [Tekton Hub](https://hub.tekton.dev/) has hundreds of community tasks ready to use.

### 5. It's not for everything

Tekton is powerful but opinionated. If you need complex conditional logic, matrix builds, or heavy UI-driven workflows, GitHub Actions or GitLab CI might be better fits. Tekton shines when you want CI/CD *inside* your cluster with Kubernetes-native tooling.

---

## The Complete Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Kubernetes (Minikube) | 1.32.0 | Local cluster |
| Tekton Pipelines | 0.65.2 | Tasks + Pipelines engine |
| Tekton Triggers | 0.36.0 | Webhook → PipelineRun |
| Tekton Dashboard | 0.69.0 | Web UI |
| Kaniko | latest | Image builds (no Docker daemon) |
| Python + Flask | 3.12 | The demo app |

---

## Try It

Everything is open source and runs on your laptop:

**👉 [github.com/23seriy/TEKTON-in-action](https://github.com/23seriy/TEKTON-in-action)**

Four scripts. Seven scenarios. Full verification at every step. From zero to a working Tekton CI/CD pipeline in 10 minutes.

If you're already running Kubernetes in production and still pushing builds through Jenkins or paying for CI/CD minutes — try Tekton. Your pipeline should be as Kubernetes-native as your application.

---

## Cleanup

When you're done:

```bash
./scripts/05-teardown.sh
```

Removes everything — Tekton, the demo namespace, and the Minikube cluster. Clean.

---

*If this was useful, give the [repo](https://github.com/23seriy/TEKTON-in-action) a ⭐ — it helps others find it.*

*Questions? Open an issue or find me on GitHub: [@23seriy](https://github.com/23seriy)*

---

**Tags:** `Tekton` `Kubernetes` `CI/CD` `DevOps` `Kaniko` `Cloud Native` `Pipelines` `Jenkins Alternative`
