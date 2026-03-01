#!/bin/bash

# Usage: ./scripts/flush-all-caches.sh [NAMESPACE]
# Default namespace is 'erpnext'

NAMESPACE=${1:-erpnext}
REDIS_HOST="cache.valkey.erpnext.asia-south1.prod.aurumor.com"
REDIS_PORT="6379"

echo "Using Namespace: $NAMESPACE"

# 1. Flush Redis
echo "------------------------------------------------"
echo "Step 1: Flushing Redis Cache ($REDIS_HOST)"
echo "------------------------------------------------"

kubectl run -n "$NAMESPACE" redis-flush-script \
    --image=redis:alpine \
    --restart=Never --rm -i \
    -- redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" flushall

if [ $? -eq 0 ]; then
    echo "✅ Redis cache flushed successfully."
else
    echo "❌ Failed to flush Redis cache."
    exit 1
fi

# 2. Get a Gunicorn Pod
echo "------------------------------------------------"
echo "Step 2: Identifying Gunicorn Pod"
echo "------------------------------------------------"

POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=erpnext-gunicorn -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
    echo "❌ No running Gunicorn pod found in namespace '$NAMESPACE'."
    exit 1
fi

echo "✅ Found Gunicorn Pod: $POD_NAME"

# 3. List Sites and Clear Bench Cache
echo "------------------------------------------------"
echo "Step 3: Clearing Bench Cache for All Sites"
echo "------------------------------------------------"

# Get list of sites (excluding common config and assets)
SITES=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- ls -1 /home/frappe/frappe-bench/sites | grep -vE "^(assets|apps.txt|common_site_config.json)$")

if [ -z "$SITES" ]; then
    echo "⚠️ No sites found."
    exit 0
fi

for SITE in $SITES; do
    echo "👉 Processing Site: $SITE"
    
    echo "   Running: bench clear-cache..."
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bench --site "$SITE" clear-cache
    
    echo "   Running: bench clear-website-cache..."
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- bench --site "$SITE" clear-website-cache
    
    echo "✅ Site $SITE cache cleared."
done

echo "------------------------------------------------"
echo "🎉 All caches cleared successfully!"
echo "------------------------------------------------"
