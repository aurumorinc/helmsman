
Here is a comprehensive `README.md` template tailored to your specific architecture. You can commit this directly to the root of your GitOps repository.

***

# 🚀 GitOps Deployments & Configuration

This repository is the **Single Source of Truth** for the deployment state of our infrastructure. It contains configuration manifests for all applications hosted on **Google Kubernetes Engine (GKE)** and **Google Cloud Run**.

## 📂 Repository Structure

We utilize a **Platform-First** directory structure. The top-level directories distinguish the deployment target (Platform), ensuring that automation tools (ArgoCD vs. CI Pipelines) operate in isolated scopes.

```text
.
├── k8s/                          # ☸️ GKE Workloads (Managed by ArgoCD)
│   ├── _cluster/                 # Cluster-wide resources (Ingress, Namespaces)
│   ├── n8n/                      # Application Name
│   │   ├── base/                 # Common Helm/Kustomize bases
│   │   ├── staging/              # Staging Environment
│   │   │   └── values.yaml       # Helm values override
│   │   └── production/           # Production Environment
│   │       └── values.yaml
│   └── authentik/
│       └── ...
│
├── run/                          # 🏃 Cloud Run Services (Managed by CI/GitHub Actions)
│   ├── my-custom-app/            # Application Name
│   │   ├── local/                # 💻 LOCAL DEV & DOCS (Ignored by Deployments)
│   │   │   ├── docker-compose.yml
│   │   │   └── README.md
│   │   ├── staging/              # Staging Environment
│   │   │   └── service.yaml      # Knative/Cloud Run Service Definition
│   │   └── production/           # Production Environment
│   │       └── service.yaml
│   └── ...
│
└── README.md
```

---

## 🛠 Deployment Workflows

### 1. Kubernetes (GKE)
*   **Location:** `k8s/`
*   **Tooling:** ArgoCD / Flux
*   **Format:** Helm Charts (via `values.yaml`) or Kustomize.

**How to Deploy:**
1.  Navigate to `k8s/<app_name>/<environment>/`.
2.  Edit `values.yaml` (e.g., update the `image.tag` or `resources`).
3.  Commit and Push to `main`.
4.  **ArgoCD** automatically detects the change and syncs the cluster state.

### 2. Cloud Run
*   **Location:** `run/`
*   **Tooling:** GitHub Actions / CI Pipelines (via `gcloud`)
*   **Format:** Knative Service YAML (`serving.knative.dev/v1`).

**How to Deploy:**
1.  Navigate to `run/<app_name>/<environment>/`.
2.  Edit `service.yaml`.
3.  Commit and Push to `main`.
4.  **CI Pipeline** triggers (filtered by the `run/` path), detects the changed service, and executes:
    ```bash
    gcloud run services replace run/<app>/<env>/service.yaml
    ```

**Understanding the App (Local Dev):**
Since Cloud Run is serverless, we cannot "run" the `service.yaml` locally.
*   Check the `run/<app>/local/` directory.
*   Review `docker-compose.yaml` to understand how the app connects to databases and services locally.
*   *Note: The `local/` folder is strictly for documentation/dev and is never deployed.*

---

## 📝 Naming Conventions & Guidelines

### The "Platform Separation" Rule
*   If an app requires persistent volumes, sidecars, or complex orchestration (e.g., **n8n, Authentik**), place it in **`k8s/`**.
*   If an app is stateless, HTTP-based, and scales to zero, place it in **`run/`**.

### Environment Folders
*   **`stag/`**: Deploys to the staging cluster/project. Used for testing new image tags.
*   **`prod/`**: Deploys to live environment. Requires Pull Request approval.

### Secrets Management
🛑 **NEVER COMMIT RAW SECRETS.**
*   We use **External Secrets Operator** (or SOPS/Sealed Secrets) to fetch secrets from Google Secret Manager.
*   Commit references to secret keys (e.g., `secretKeyRef`), not the actual values.

---

## ➕ Adding a New Application

### Scenario A: Adding an Open Source App (Helm) to GKE
1.  Create `k8s/<app-name>`.
2.  Add a `base/` folder with `Chart.yaml` pointing to the upstream repo.
3.  Create `staging/values.yaml` and `production/values.yaml`.
4.  Add the application to the ArgoCD registry.

### Scenario B: Adding a Custom App to Cloud Run
1.  Create `run/<app-name>`.
2.  Create `local/docker-compose.yaml` (copy from the app source repo for reference).
3.  Create `staging/service.yaml` defining the image and env vars.
4.  Ensure the CI Pipeline has permissions to deploy this new service.

---

## 🔗 Related Repositories

*   **`bedrock` (Terraform):** Manages the VPCs, GKE Clusters, SQL Instances, and IAM roles. *Infrastructure changes happen there; Deployment changes happen here.*
*   **`app-source-code`:** The actual source code for our custom applications.