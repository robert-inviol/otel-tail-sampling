# Deployment Guide

## Prerequisites

- Azure subscription
- Azure CLI installed and logged in
- GitHub account
- Application Insights resource (or we'll create one)

## Step-by-Step Deployment

### 1. Create Azure Application Insights

```bash
# Set variables
RESOURCE_GROUP="otel-rg"
LOCATION="eastus"
APP_INSIGHTS_NAME="otel-app-insights"
WORKSPACE_NAME="otel-workspace"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME

# Create Application Insights
az monitor app-insights component create \
  --app $APP_INSIGHTS_NAME \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --workspace $WORKSPACE_NAME

# Get connection string (SAVE THIS!)
CONNECTION_STRING=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query connectionString -o tsv)

echo "Connection String: $CONNECTION_STRING"

# Get ingestion endpoint
INGESTION_ENDPOINT=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query ingestionEndpoint -o tsv)

echo "Ingestion Endpoint: ${INGESTION_ENDPOINT}/v2.1/track"
```

### 2. Create Azure App Service

```bash
# Set variables
APP_SERVICE_NAME="otel-tail-sampling"  # Must be globally unique!
APP_PLAN_NAME="otel-plan"

# Create App Service Plan (B2 tier for 3.5GB RAM)
az appservice plan create \
  --name $APP_PLAN_NAME \
  --resource-group $RESOURCE_GROUP \
  --is-linux \
  --sku B2

# Create Web App
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $APP_PLAN_NAME \
  --name $APP_SERVICE_NAME \
  --deployment-container-image-name otel/opentelemetry-collector-contrib:0.96.0

# Configure container settings
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $APP_SERVICE_NAME \
  --settings \
    WEBSITES_PORT=4318 \
    WEBSITES_CONTAINER_START_TIME_LIMIT=600 \
    DOCKER_REGISTRY_SERVER_URL="https://index.docker.io" \
    AZURE_MONITOR_ENDPOINT="${INGESTION_ENDPOINT}/v2.1/track" \
    APPLICATIONINSIGHTS_CONNECTION_STRING="$CONNECTION_STRING"

# Enable container logging
az webapp log config \
  --resource-group $RESOURCE_GROUP \
  --name $APP_SERVICE_NAME \
  --docker-container-logging filesystem

echo "App Service URL: https://${APP_SERVICE_NAME}.azurewebsites.net"
```

### 3. Create GitHub Repository

```bash
# In your local repo directory
cd /home/robert/otel-tail-sampling

# Create repo on GitHub (requires gh CLI)
gh repo create otel-tail-sampling --public --source=. --remote=origin

# Or manually:
# 1. Go to https://github.com/new
# 2. Create repository named "otel-tail-sampling"
# 3. Then run:
git remote add origin https://github.com/YOUR_USERNAME/otel-tail-sampling.git
git push -u origin main
```

### 4. Create Service Principal for GitHub Actions

```bash
# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal
az ad sp create-for-rbac \
  --name "github-otel-deploy" \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP \
  --sdk-auth

# Output will look like:
# {
#   "clientId": "xxx",
#   "clientSecret": "xxx",
#   "subscriptionId": "xxx",
#   "tenantId": "xxx",
#   ...
# }
# SAVE THIS ENTIRE JSON OUTPUT!
```

### 5. Configure GitHub Secrets

Go to your GitHub repo: `https://github.com/YOUR_USERNAME/otel-tail-sampling/settings/secrets/actions`

Click **"New repository secret"** and add:

1. **`AZURE_CREDENTIALS`**
   ```json
   {
     "clientId": "xxx",
     "clientSecret": "xxx",
     "subscriptionId": "xxx",
     "tenantId": "xxx",
     "resourceManagerEndpointUrl": "https://management.azure.com/"
   }
   ```

2. **`AZURE_MONITOR_ENDPOINT`**
   ```
   https://xxx.in.applicationinsights.azure.com/v2.1/track
   ```

3. **`APPLICATIONINSIGHTS_CONNECTION_STRING`**
   ```
   InstrumentationKey=xxx;IngestionEndpoint=https://xxx.in.applicationinsights.azure.com/
   ```

### 6. Update Workflow File

Edit `.github/workflows/deploy.yml` and update:

```yaml
env:
  AZURE_WEBAPP_NAME: otel-tail-sampling    # Your App Service name
```

### 7. Deploy!

```bash
# Commit and push
git add .
git commit -m "Configure deployment"
git push origin main
```

GitHub Actions will automatically:
1. Build Docker image
2. Push to GitHub Container Registry
3. Deploy to Azure App Service

### 8. Verify Deployment

```bash
# Check deployment status on GitHub
# Go to: https://github.com/YOUR_USERNAME/otel-tail-sampling/actions

# Once deployed, test endpoints
curl https://${APP_SERVICE_NAME}.azurewebsites.net:13133/
curl https://${APP_SERVICE_NAME}.azurewebsites.net:8888/metrics

# View logs
az webapp log tail --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP
```

### 9. Test End-to-End

```bash
# Send test trace
curl -X POST "https://${APP_SERVICE_NAME}.azurewebsites.net:4318/v1/traces" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-service"}
        }]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5b8efff798038103d269b633813fc60c",
          "spanId": "eee19b7ec3c1b174",
          "name": "test-error",
          "kind": 1,
          "startTimeUnixNano": "1633000000000000000",
          "endTimeUnixNano": "1633000001000000000",
          "status": {
            "code": 2,
            "message": "Test error"
          }
        }]
      }]
    }]
  }'

# Check Application Insights
# Azure Portal → Your App Insights → Transaction search
# You should see the test trace appear within 1-2 minutes
```

## Configuration Management

### Update Configuration Without Redeploying

You can update environment variables without redeploying:

```bash
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $APP_SERVICE_NAME \
  --settings \
    NEW_SETTING=value

# Restart to apply
az webapp restart --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP
```

### Update Collector Configuration

To update `otel-collector-config.yaml`:
1. Edit the file locally
2. Commit and push
3. GitHub Actions will rebuild and redeploy

## Scaling Considerations

### Single Instance (Current Setup)
- Good for: Up to 1000 traces/sec
- Memory: 3.5GB (B2 tier)
- Limitation: All spans of a trace must hit same instance

### Multiple Instances (Advanced)
For higher throughput, you need a two-tier setup:

```
Apps → Load Balancer → Collectors (Layer 1)
                            ↓
                    Load Balancing Exporter
                            ↓
                  Collectors with Tail Sampling (Layer 2)
                            ↓
                  Application Insights
```

See: [Scaling Tail Sampling](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/processor/tailsamplingprocessor/README.md#scaling)

## Monitoring the Collector

### View Metrics

```bash
# Prometheus metrics
curl https://${APP_SERVICE_NAME}.azurewebsites.net:8888/metrics

# Key metrics to watch:
# - otelcol_processor_refused_spans
# - otelcol_processor_dropped_spans
# - otelcol_exporter_sent_spans
# - go_memstats_alloc_bytes
```

### View Logs

```bash
# Live tail
az webapp log tail --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP

# Download logs
az webapp log download --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP
```

### Set Up Alerts

```bash
# Alert on high memory usage
az monitor metrics alert create \
  --name otel-high-memory \
  --resource-group $RESOURCE_GROUP \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_SERVICE_NAME" \
  --condition "avg MemoryWorkingSet > 3000000000" \
  --description "OTEL collector using >3GB memory"

# Alert on collector errors
az monitor metrics alert create \
  --name otel-collector-errors \
  --resource-group $RESOURCE_GROUP \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_SERVICE_NAME" \
  --condition "count Http5xx > 10" \
  --description "OTEL collector returning 5xx errors"
```

## Cost Optimization

### Current Setup Cost (Monthly Estimate)
- **App Service B2**: ~$70/month
- **Application Insights**: Pay-per-GB ingested
  - With 90% reduction: ~$10-50/month (depends on volume)
- **Total**: ~$80-120/month

### Reduce Costs Further

1. **Adjust sampling percentage**:
   ```yaml
   probabilistic-sample:
     sampling_percentage: 5  # Reduce to 5%
   ```

2. **Increase latency threshold**:
   ```yaml
   slow-traces:
     threshold_ms: 10000  # Only keep >10s traces
   ```

3. **Use smaller App Service tier** (if lower volume):
   ```bash
   az appservice plan update --name $APP_PLAN_NAME --sku B1
   ```

## Cleanup

To delete all resources:

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```
