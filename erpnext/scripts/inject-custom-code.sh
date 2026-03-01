#!/bin/bash
set -e

NAMESPACE="erpnext"

# Item Category (ERPNext App)
LOCAL_PATH_CAT="backups/item_category"
REMOTE_PATH_CAT="/home/frappe/frappe-bench/apps/erpnext/erpnext/setup/doctype/item_category"

# Item Tag (Frappe App)
LOCAL_PATH_TAG="backups/item_tag"
REMOTE_PATH_TAG="/home/frappe/frappe-bench/apps/frappe/frappe/desk/doctype/item_tag"

echo "Finding backend pods..."
# Filter for backend pods
PODS=$(kubectl get pods -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep -E "worker|gunicorn|scheduler|socketio")

for POD in $PODS; do
    echo "---------------------------------------------------"
    echo "Injecting code into $POD..."
    
    # Inject Item Category
    kubectl exec -n $NAMESPACE $POD -- mkdir -p "$REMOTE_PATH_CAT"
    kubectl cp "$LOCAL_PATH_CAT/item_category.js" "$NAMESPACE/$POD:$REMOTE_PATH_CAT/item_category.js"
    kubectl cp "$LOCAL_PATH_CAT/item_category.json" "$NAMESPACE/$POD:$REMOTE_PATH_CAT/item_category.json"
    kubectl cp "$LOCAL_PATH_CAT/item_category.py" "$NAMESPACE/$POD:$REMOTE_PATH_CAT/item_category.py"
    kubectl cp "$LOCAL_PATH_CAT/test_item_category.py" "$NAMESPACE/$POD:$REMOTE_PATH_CAT/test_item_category.py"
    kubectl cp "$LOCAL_PATH_CAT/__init__.py" "$NAMESPACE/$POD:$REMOTE_PATH_CAT/__init__.py"
    
    # Inject Item Tag
    kubectl exec -n $NAMESPACE $POD -- mkdir -p "$REMOTE_PATH_TAG"
    kubectl cp "$LOCAL_PATH_TAG/item_tag.js" "$NAMESPACE/$POD:$REMOTE_PATH_TAG/item_tag.js"
    kubectl cp "$LOCAL_PATH_TAG/item_tag.json" "$NAMESPACE/$POD:$REMOTE_PATH_TAG/item_tag.json"
    kubectl cp "$LOCAL_PATH_TAG/item_tag.py" "$NAMESPACE/$POD:$REMOTE_PATH_TAG/item_tag.py"
    kubectl cp "$LOCAL_PATH_TAG/test_item_tag.py" "$NAMESPACE/$POD:$REMOTE_PATH_TAG/test_item_tag.py"
    kubectl cp "$LOCAL_PATH_TAG/__init__.py" "$NAMESPACE/$POD:$REMOTE_PATH_TAG/__init__.py"

    echo "Copied files to $POD"
done

echo "---------------------------------------------------"
MIGRATE_POD=$(echo "$PODS" | grep "worker" | head -n 1)

if [ -n "$MIGRATE_POD" ]; then
    echo "Running bench migrate on $MIGRATE_POD..."
    kubectl exec -n $NAMESPACE "$MIGRATE_POD" -- bench --site erpnext.capybaara.com migrate
    
    echo "Clearing cache on $MIGRATE_POD..."
    kubectl exec -n $NAMESPACE "$MIGRATE_POD" -- bench --site erpnext.capybaara.com clear-cache
else
    echo "No worker pod found to run migrate!"
    exit 1
fi

echo "---------------------------------------------------"
echo "Code injection and migration complete."
echo "WARNING: These changes are ephemeral. If pods restart, this code will be lost."
