# Connect VS Code to your Cluster

**Concept:**
Your computer needs a "kubeconfig" file. This file acts like a digital ID card and map. It tells tools like VS Code and `kubectl` where your cluster is and proves you have permission to access it.

**Action:**
Open your terminal (in VS Code or separately) and run the following command to log in and fetch the credentials.

```bash
# 1. Login to Google Cloud
gcloud auth login

# 2. Get credentials for your specific cluster
gcloud container clusters get-credentials asia-south1-autopilot-cluster --region asia-south1 --project au-basalt-prod-rvee3b

```

**Verify in VS Code:**

1. Click the **Kubernetes icon** on the left sidebar of VS Code.
2. You should see your cluster `fcrm-db-asia-south1-prod-cluster-hsxfr6` listed.
3. Right-click it and select **"Set as Context"** (this makes it the active cluster).


# Replace variables with your cluster details
gcloud container clusters describe asia-south1-autopilot-cluster > \
  --region asia-south1 \
  --format="value(nodeConfig.serviceAccount)"

```
gcloud iam service-accounts add-iam-policy-binding cloud-sql-client@au-waha-prod-335035.iam.gserviceaccount.com \
    --member "serviceAccount:au-basalt-prod-rvee3b.svc.id.goog[waha/cloud-sql-client]" \
    --role "roles/iam.workloadIdentityUser" \
    --project "au-waha-prod-335035"
```