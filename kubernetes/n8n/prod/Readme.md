# Troubleshooting Guide: n8n on Kubernetes

This guide covers common troubleshooting commands and scenarios encountered when managing n8n deployments on Kubernetes.

## 1. Persistent Volumes (PV) & Claims (PVC)

### Issue: PV Stuck in "Terminating"
**Symptom:** You deleted a PersistentVolume, but it hangs in the `Terminating` state.
**Cause:** The PV has a finalizer (`kubernetes.io/pv-protection`) waiting for the associated Claim (PVC) to be deleted. If the PVC is already gone or the link is broken, the PV waits indefinitely.

**Commands:**
```bash
# Check PV status
kubectl get pv n8n-data

# Force delete (remove finalizers)
kubectl patch pv n8n-data -p '{"metadata":{"finalizers":null}}'
```
> **Warning:** If `persistentVolumeReclaimPolicy` is `Retain`, the underlying data on the storage (e.g., NFS, Filestore) is NOT deleted. You must clean it up manually if desired.

### Inspecting Claims
```bash
# List all PVCs in the namespace
kubectl get pvc -n n8n

# Describe a specific claim to see events (mounting errors, capacity issues)
kubectl describe pvc data -n n8n
```

## 2. Kustomize & Helm Integration

### Issue: "must specify --enable-helm"
**Symptom:** `kubectl kustomize .` fails with an error about `HelmChartInflationGenerator`.
**Cause:** Your `kustomization.yaml` uses the `helmCharts` field, which requires the Helm plugin to be explicitly enabled.

**Commands:**
```bash
# Build manifests with Helm enabled
kubectl kustomize --enable-helm .

# Build and apply in one step
kubectl kustomize --enable-helm . | kubectl apply -f -
```

### Verifying Rendered Manifests
Before applying, it's good practice to inspect what Kustomize is generating:
```bash
# Check the output to ensure Helm values are being applied correctly
kubectl kustomize --enable-helm . > debug_manifest.yaml
```

## 3. Pod & Deployment Health

### Checking Pod Status
```bash
# List all pods
kubectl get pods -n n8n

# Watch pods update in real-time
kubectl get pods -n n8n -w
```

### Investigating Crashes (CrashLoopBackOff)
```bash
# Get logs from a specific pod
kubectl logs <pod-name> -n n8n

# If the pod has multiple containers (e.g., n8n + cloud-sql-proxy)
kubectl logs <pod-name> -c n8n -n n8n
kubectl logs <pod-name> -c cloud-sql-proxy -n n8n

# Describe the pod to see events (OOMKilled, Liveness probe failures)
kubectl describe pod <pod-name> -n n8n
```

## 4. Secret Management (External Secrets)

### Debugging ExternalSecret Sync
If your secrets aren't showing up as Kubernetes Secrets:
```bash
# Check the ExternalSecret resource status
kubectl get externalsecret -n n8n

# Describe to see sync errors (e.g., permission denied, key not found)
kubectl describe externalsecret <name> -n n8n

# Check the SecretStore status
kubectl get secretstore -n n8n
kubectl describe secretstore gcp-secret-manager -n n8n
```

## 5. Networking & Services

### Port Forwarding
Access internal services locally for testing:
```bash
# Forward n8n service port to localhost:5678
kubectl port-forward svc/n8n -n n8n 5678:5678

# Forward Cloud SQL Proxy (if running as a separate service)
kubectl port-forward svc/cloud-sql-proxy -n n8n 5432:5432
```
