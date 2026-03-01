# ERPNext Deployment on Kubernetes

This guide outlines the steps to deploy the ERPNext application and perform manual site creation if necessary.

## Prerequisites

*   **Kubernetes Cluster**: A running K8s cluster.
*   **kubectl**: CLI tool configured to communicate with your cluster.
*   **Helm**: Required for Kustomize to inflate the ERPNext Helm chart.

## Deployment Steps

### 1. Create Namespace

Ensure the target namespace exists. The configuration is set to use `erpnext`.

```bash
kubectl create namespace erpnext
```

### 1.1 Configure Workload Identity

Bind the Kubernetes Service Account to the Google Service Account to allow access to secrets.

```bash
gcloud iam service-accounts add-iam-policy-binding "secret-manager-secret-accessor@au-erpnext-prod-485714.iam.gserviceaccount.com" \
  --project="au-erpnext-prod-485714" \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:au-basalt-prod-rvee3b.svc.id.goog[erpnext/secret-manager-secret-accessor]"
```

*   **GSA Project**: `au-erpnext-prod-485714` (Where the Service Account exists)
*   **Cluster Project**: `au-basalt-prod-rvee3b` (Where the GKE Cluster runs)

### 1.2 Configure Backup Storage Identity

Bind the Backup Service Account to the Google Service Account to allow access to GCS buckets.

```bash
gcloud iam service-accounts add-iam-policy-binding storage-folder-admin@au-erpnext-prod-485714.iam.gserviceaccount.com \
  --project=au-erpnext-prod-485714 \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:au-basalt-prod-rvee3b.svc.id.goog[erpnext/storage-folder-admin]"
```

### 1.3 Configure GCS Lifecycle

Apply the lifecycle policy to the GCS bucket to manage backup retention (e.g., delete hourly backups after 7 days).

```bash
gcloud storage buckets update gs://erpnext-backups-asia-bucket-8ngeal --lifecycle-file=lifecycle-file.json
```

### 2. Apply Configuration

Use `kustomize` with Helm enabled to generate and apply the manifests.

```bash
kubectl kustomize --enable-helm . | kubectl apply -f -
```

### 3. Verify Deployment

Wait for the pods to be in `Running` state.

```bash
kubectl get pods -n crm
```

You should see pods for MariaDB, MaxScale, and ERPNext components (worker, gunicorn, scheduler, etc.).

---

## Manual Site Creation

If the automated site creation job fails or if you need to create a site manually, follow these steps.

### Option A: Using the Helper Script

A script is provided in `scripts/create-site.sh` to automate the manual process.

```bash
cd scripts
./create-site.sh <site-name> <namespace>
# Example: ./create-site.sh [SITE_NAME] [NAMESPACE]
```

### Option B: Step-by-Step Manual Creation

#### 1. Identify the Worker Pod

You need to execute the site creation command from within a pod that has the `bench` CLI and access to the shared volume (usually a worker pod).

```bash
# Find a worker pod
kubectl get pods -n crm -l app.kubernetes.io/name=erpnext-worker
```

Select one of the worker pods (e.g., `crm-worker-d-xxxxx`).

#### 2. Prerequisite: Fix Missing Dependencies

If using the custom image `erpnext-hrms-crm-offsite_backup-frappe_whatsapp`, you may encounter a `ModuleNotFoundError: No module named 'pkg_resources'` error. This is due to a missing dependency in the Python environment.

Fix it by installing `setuptools` inside the pod before creating the site:

```bash
kubectl exec -n crm <worker-pod-name> -- /home/frappe/frappe-bench/env/bin/pip install setuptools
```

#### 3. Execute `bench new-site`

Run the site creation command. Ensure you use the correct app names (underscores, not hyphens for some apps).

```bash
kubectl exec -n [NAMESPACE] <worker-pod-name> -- bench new-site [SITE_NAME] \
  --no-mariadb-socket \
  --db-type=mariadb \
  --db-host=maxscale.[NAMESPACE].svc.cluster.local \
  --db-port=3306 \
  --admin-password=<your-admin-password> \
  --mariadb-root-username=[DB_USER] \
  --mariadb-root-password=<db-root-password> \
  --install-app=crm \
  --install-app=offsite_backups \
  --install-app=frappe_whatsapp \
  --force
```

> **Note:** The `--no-mariadb-socket` flag is required to force a TCP connection.
> **Note:** Use `offsite_backups` (plural, underscore) and `frappe_whatsapp` (underscore) as app names.

#### 4. Enable Scheduler

After the site is created, enable the scheduler for background jobs.

```bash
bench --site <site-name> enable-scheduler
```

### Verification

1.  **Site Config**: Ensure `sites/<site-name>/site_config.json` exists in the persistent volume.
2.  **Access**: Try accessing the site URL in your browser.

## Scaling & Performance

### Vertical Scaling (CPU/RAM)
Vertical Pod Autoscaling (VPA) is configured to automatically adjust CPU and Memory requests based on usage.
*   **Mode**: `Auto` (Pods will restart to apply changes).
*   **Configuration**: See `prod/mariadb-vpa.yaml`.

### Storage Scaling
The Persistent Volumes do **not** auto-expand.
*   To resize, manually edit `prod/mariadb.yaml` (for DB) or `prod/persistent-volume.yaml` (for Files), update the size, and apply. The `resizeInUseVolumes: true` setting allows online expansion.

## Troubleshooting

### 1. Pods stuck in `ContainerCreating`
Check for **NFS Mount Errors** (`kubectl describe pod ...`).
*   **Error**: `mount failed: exit status 32 ... No such file or directory`.
*   **Fix**: Ensure the `path` in `prod/persistent-volume.yaml` matches the actual Share Name on your GCP Filestore (e.g., `/share1` or `/vol1`).

### 2. Gunicorn `Init:ErrImagePull`
*   **Error**: `manifest for ...:1.57.0-rc2 not found`.
*   **Fix**: Ensure `prod/values.yaml` uses a valid image tag (e.g., `v16.3.0-rc13`) in the `initContainers` section.

### 3. ExternalSecret `SecretSyncedError`
*   **Error**: `Permission 'iam.serviceAccounts.getAccessToken' denied`.
*   **Fix**: Re-run the Workload Identity binding command (See Step 1.1) using the correct **Cluster Project ID** in the `--member` flag.

### 4. GCS Backup Troubleshooting
*   **Error**: `MountVolume.SetUp failed ... failed to find the sidecar container`
    *   **Cause**: Missing GKE Autopilot sidecar injection annotation.
    *   **Fix**: Ensure `gke-gcsfuse/volumes: "true"` annotation is present in the CronJob Pod template.
*   **Error**: `Unauthenticated ... failed to prepare storage service`
    *   **Cause**: Workload Identity not correctly configured.
    *   **Fix**: Run the Workload Identity binding command (Step 1.2).
*   **Error**: `mkdir: cannot create directory ... Permission denied`
    *   **Cause**: The `frappe` user (UID 1000) cannot write to the GCS mount (default root).
    *   **Fix**: Ensure `mountOptions` in `prod/persistent-volume.yaml` include `uid=1000` and `gid=1000`.
