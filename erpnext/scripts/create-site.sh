#!/bin/bash

# Script to manually create an ERPNext site in Kubernetes
# Usage: ./create-site.sh [SITE_NAME] [NAMESPACE]

SITE_NAME=${1:-"erpnext.pennyjaar.com"}
NAMESPACE=${2:-"erpnext"}
DB_HOST="maxscale.erpnext.svc.cluster.local"
DB_PORT="3306"
DB_ROOT_USER="erpnext"

echo "Using Namespace: $NAMESPACE"
echo "Target Site: $SITE_NAME"

# 1. Fetch Credentials from Kubernetes Secrets
echo "Fetching credentials..."
DB_ROOT_PASSWORD=$(kubectl get secret password -n "$NAMESPACE" -o jsonpath="{.data.user-password}" | base64 -d)
ADMIN_PASSWORD=$(kubectl get secret password -n "$NAMESPACE" -o jsonpath="{.data.admin-password}" | base64 -d)

if [ -z "$DB_ROOT_PASSWORD" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo "Error: Could not fetch passwords from secret 'password' in namespace $NAMESPACE"
    exit 1
fi

# 2. Find a Worker Pod
# Select any running worker pod
WORKER_POD=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running -o custom-columns=":metadata.name" | grep "worker" | head -n 1)

if [ -z "$WORKER_POD" ]; then
    echo "Error: No running worker pod found in namespace $NAMESPACE"
    exit 1
fi

echo "Using worker pod: $WORKER_POD"

# 3. Install Prerequisites (Workaround for missing dependency)
echo "Installing missing dependencies (setuptools)..."
kubectl exec -n "$NAMESPACE" "$WORKER_POD" -- /home/frappe/frappe-bench/env/bin/pip install setuptools

# 4. Execute bench new-site
echo "Creating site (this may take a few minutes)..."
kubectl exec -n "$NAMESPACE" "$WORKER_POD" -- bash -c "bench new-site $SITE_NAME \
  --mariadb-user-host-login-scope='%' \
  --db-type=mariadb \
  --db-host=$DB_HOST \
  --db-port=$DB_PORT \
  --admin-password='$ADMIN_PASSWORD' \
  --mariadb-root-username=$DB_ROOT_USER \
  --mariadb-root-password='$DB_ROOT_PASSWORD' \
  --install-app=erpnext \
  --install-app=offsite_backups \
  --install-app=hrms \
  --force"

if [ $? -eq 0 ]; then
    echo "Site created successfully."

    # 5. Enable Scheduler
    echo "Enabling scheduler..."
    kubectl exec -n "$NAMESPACE" "$WORKER_POD" -- bash -c "bench --site $SITE_NAME enable-scheduler"
    echo "Scheduler enabled. Done!"
else
    echo "Error: Site creation failed."
    exit 1
fi
