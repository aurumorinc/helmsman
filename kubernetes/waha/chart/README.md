# Waha Helm Chart

This Helm chart deploys Waha (WhatsApp HTTP API) with support for:
- A main dashboard instance.
- Multiple user-specific instances.
- An internal Nginx Gateway to route traffic (`/` -> main, `/user/{name}/` -> user instance).
- External Secrets integration for secure password management.

## Prerequisites

- Kubernetes cluster
- Helm 3+
- External Secrets Operator installed
- GCP Secret Manager (or another provider) configured with the required secrets.

## Configuration

### Secrets
Ensure your Secret Manager has the following keys (configurable in `values.yaml`):

| Key | Description |
|-----|-------------|
| `WAHA_DASHBOARD_PASSWORD` | Password for the dashboard (shared). |
| `WHATSAPP_SWAGGER_PASSWORD` | Password for Swagger (shared). |
| `WAHA_API_KEY` | API Key for Waha (shared). |
| `WAHA_S3_ACCESS_KEY_ID` | S3 Access Key. |
| `WAHA_S3_SECRET_ACCESS_KEY` | S3 Secret Key. |
| `WHATSAPP_SESSIONS_POSTGRESQL_URL` | Full DB URL for the **Main** instance. |
| `DATABASE_PASSWORD` | **Raw Password** for the database user (used to construct user DB URLs). |

### User
To add user, update `values.yaml`:

```yaml
user:
  - name: client1
    baseUrl: "https://waha.aurumor.com/user/client1"
    publicUrl: "https://waha.aurumor.com/user/client1"
    # dashboardUsername: "client1" # Optional override
  - name: client2
    baseUrl: "https://waha.aurumor.com/user/client2"
    publicUrl: "https://waha.aurumor.com/user/client2"
```

The system will automatically configure the database connection string for `client1` as:
`postgres://waha:<PASSWORD>@10.0.1.55:5432/waha-client1`

## Deployment

1. **Install/Upgrade the Chart**:
   ```bash
   helm upgrade --install waha ./waha/chart --namespace waha --create-namespace
   ```

2. **Verify**:
   - The `waha` Service should point to the Nginx Gateway.
   - Accessing `/` should route to the Main Dashboard.
   - Accessing `/user/client1/` should route to the Client 1 instance.

## Architecture

- **Gateway**: Nginx reverse proxy. Handles routing based on path.
- **Main Instance**: The primary Waha deployment.
- **User Instances**: Scalable independent deployments per user.
- **Database**: All instances share the Postgres host but use different databases (`waha` for main, `waha-{user}` for user).
