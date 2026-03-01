# CRM Deployment (ERPNext/Frappe)

This directory contains the Kubernetes manifests to deploy a highly-available, production-ready CRM application based on ERPNext/Frappe. It uses a combination of Kustomize, Helm, and Custom Operators to orchestrate the entire stack.

## 🏗 Architecture Overview

The CRM deployment is decoupled into several highly available components, replacing the default in-chart dependencies with robust external or operator-managed equivalents to suit a production GCP (Google Cloud Platform) environment.

### Key Components

1. **ERPNext Application Stack (Helm)**:
   - Uses the official `erpnext` Helm chart (`https://helm.erpnext.com` v8.0.19) integrated via Kustomize `helmCharts`.
   - **Gunicorn Workers**: Scalable Python workers serving the Frappe application, configured with `initContainers` to sync assets to shared storage.
   - **Nginx**: Serves static assets and acts as an internal reverse proxy, configured with annotations for Google Cloud Load Balancing (`X-Forwarded-For` mapping, IP whitelists).
   - **Background Workers**: Specialized workers (`default`, `short`, `long`, `scheduler`) handle queued background tasks.
   - **WebSocket (Socket.io)**: For real-time updates.

2. **Database (MariaDB Operator)**:
   - The native Helm database is disabled. Instead, it uses the **MariaDB Operator** (`k8s.mariadb.com/v1alpha1`).
   - A 2-node replicated MariaDB cluster (`mariadb.yaml`).
   - **MaxScale** proxy (`maxscale.yaml`) sits in front of the DB, handling automatic failover and read/write query splitting (port 3306 routes writes to the primary and balances reads across replicas).

3. **Caching & Queues (External Redis / Valkey)**:
   - Internal Redis and Dragonfly are disabled.
   - Connects to an external GCP Memorystore (Valkey) instance for both caching and Celery queues (`cache.valkey...` and `queue.valkey...`).

4. **Persistence & Storage**:
   - **Sites / Assets**: Stored on GCP Filestore (NFS). Mounted via a PersistentVolume (`crm-sites`) with `ReadWriteMany` access mode, ensuring all workers and Nginx instances share the exact same application state.
   - **Backups**: GCS Fuse CSI driver mounts a Google Cloud Storage bucket (`crm-backups-asia-bucket...`) as a filesystem for seamless off-cluster backup storage.

5. **Backup & Disaster Recovery**:
   - **Database Backups**: Managed by the MariaDB Operator (`backup.yaml`), executing hourly, daily, weekly, and monthly logical backups directly to a GCS S3-compatible endpoint.
   - **Application Backups**: Managed via Kubernetes `CronJobs` (`cronjob.yaml`) using a custom bash script. This backs up site files directly into the GCS Fuse mounted volume.

6. **Site Creation & Migration**:
   - Orchestrated via Helm hooks / Jobs (`jobs.createSite`, `jobs.migrate` in `values.yaml`).
   - Automatically provisions `crm.pennyjaar.com` and `crm.capybaara.com` and installs `crm`, `frappe_crm`, and `frappe_chatwoot` apps.

## 📋 Prerequisites

Before deploying, ensure the following infrastructure and dependencies exist:

1. **Kubernetes Operators & CRDs**:
   - MariaDB Operator installed in the cluster.
   - External Secrets Operator installed.
   - GCS Fuse CSI Driver enabled on the GKE cluster.
2. **External Infrastructure (GCP)**:
   - GCP Filestore NFS instance created and accessible. Update the IP/Host in `persistent-volume.yaml`.
   - GCP Memorystore (Valkey/Redis) instances for cache and queue.
   - Google Cloud Storage buckets created for backups and DB dumps.
3. **Secrets Management**:
   - `SecretStore` configured to connect to GCP Secret Manager.
   - Secrets pushed to your Secret Manager:
     - MariaDB root password.
     - S3 access keys for DB backup uploading.

## 🚀 Deployment Instructions

This project uses Kustomize to patch and stitch everything together. It applies base manifests, inflates the Helm chart, and patches components for compatibility.

To deploy the CRM stack:

```bash
# Navigate to the prod overlay directory
cd prod

# Preview the manifested YAML
kubectl kustomize .

# Apply the deployment to the cluster
kubectl apply -k .
```

*Note: The Kustomization automatically sets the namespace to `crm`.*

## ⚙️ Configuration Details (`values.yaml`)

The `prod/values.yaml` is the heart of the application tuning. Key sections include:

- **Autoscaling**: Enabled for Nginx and Gunicorn workers (scaling based on CPU utilization).
- **Probes**: Configured with explicit `Host` headers (`crm.pennyjaar.com`) to satisfy GCP Health Checks.
- **Jobs**: 
  - `configure`: Adjusts NFS volume permissions and writes `common_site_config.json`.
  - `createSite`: Bootstraps new tenant databases and installs the required Frappe applications.

## 🛠 Operational Tasks

### Accessing the Frappe Bench Console
To run `bench` commands manually, exec into the Python worker pod:

```bash
# Find the worker pod
kubectl get pods -n crm -l app.kubernetes.io/name=erpnext,app.kubernetes.io/component=worker-gunicorn

# Exec into the pod
kubectl exec -it <worker-pod-name> -n crm -- bash

# Once inside, run bench commands
bench --site crm.pennyjaar.com console
```

### Flushing Redis Cache
If you need to clear the cache manually, a helper job is provided:

```bash
kubectl create -f prod/job.yaml
# Or, if already created:
kubectl replace --force -f prod/job.yaml
```

### Monitoring Database Replication
Since MaxScale and the MariaDB Operator handle DB routing, you can check replication status by querying the MariaDB custom resource:

```bash
kubectl get mariadb mariadb -n crm
kubectl get maxscale maxscale -n crm
```

### Reviewing Backups
- **Database Backups**: Check the status of MariaDB Backup CRDs (`kubectl get backups -n crm`).
- **File Backups**: Check the CronJob history (`kubectl get jobs -n crm | grep backup`).
- **Storage**: Verify directly via the GCP Console in your configured Cloud Storage buckets.