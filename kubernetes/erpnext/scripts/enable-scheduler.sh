#!/bin/bash

# Usage: ./scripts/enable-scheduler.sh [NAMESPACE]
# Default namespace is 'erpnext'

NAMESPACE=${1:-erpnext}

echo "Using Namespace: $NAMESPACE"

# 1. Get a Gunicorn Pod
echo "------------------------------------------------"
echo "Step 1: Identifying Gunicorn Pod"
echo "------------------------------------------------"

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=erpnext-gunicorn -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
    echo "❌ No running Gunicorn pod found in namespace '$NAMESPACE'."
    exit 1
fi

echo "✅ Found Gunicorn Pod: $POD_NAME"

# 2. List Sites and Enable Scheduler
echo "------------------------------------------------"
echo "Step 2: Enabling Scheduler for All Sites"
echo "------------------------------------------------"

# Get list of sites (excluding common config and assets)
SITES=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- ls -1 /home/frappe/frappe-bench/sites | grep -vE "^(assets|apps.txt|common_site_config.json)$")

if [ -z "$SITES" ]; then
    echo "⚠️ No sites found."
    exit 0
fi

for SITE in $SITES; do
    echo "👉 Processing Site: $SITE"
    
    echo "   Running: bench scheduler enable..."
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bench --site "$SITE" scheduler enable
    
    if [ $? -eq 0 ]; then
        echo "✅ Scheduler enabled for site $SITE."
    else
        echo "❌ Failed to enable scheduler for site $SITE."
    fi
done

echo "------------------------------------------------"
echo "🎉 Scheduler enabled for all sites!"
echo "------------------------------------------------"
