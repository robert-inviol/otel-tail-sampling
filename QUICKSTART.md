# Quick Start Guide

## 🚀 5-Minute Setup

### 1. Create Azure Resources (2 min)

```bash
# Variables (customize these!)
RESOURCE_GROUP="otel-rg"
APP_INSIGHTS_NAME="otel-app-insights"
APP_SERVICE_NAME="otel-tail-sampling"  # Must be globally unique!

# Create everything
az group create --name $RESOURCE_GROUP --location eastus

az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name otel-workspace

az monitor app-insights component create \
  --app $APP_INSIGHTS_NAME \
  --location eastus \
  --resource-group $RESOURCE_GROUP \
  --workspace otel-workspace

az appservice plan create \
  --name otel-plan \
  --resource-group $RESOURCE_GROUP \
  --is-linux \
  --sku B2

az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan otel-plan \
  --name $APP_SERVICE_NAME \
  --deployment-container-image-name otel/opentelemetry-collector-contrib:0.96.0
```

### 2. Get Connection Info (1 min)

```bash
# Get Application Insights connection string
CONNECTION_STRING=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query connectionString -o tsv)

# Get ingestion endpoint
INGESTION_ENDPOINT=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query ingestionEndpoint -o tsv)

echo "CONNECTION_STRING: $CONNECTION_STRING"
echo "ENDPOINT: ${INGESTION_ENDPOINT}/v2.1/track"
```

### 3. Configure App Service (1 min)

```bash
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $APP_SERVICE_NAME \
  --settings \
    WEBSITES_PORT=4318 \
    AZURE_MONITOR_ENDPOINT="${INGESTION_ENDPOINT}/v2.1/track" \
    APPLICATIONINSIGHTS_CONNECTION_STRING="$CONNECTION_STRING"
```

### 4. Push to GitHub (1 min)

```bash
cd /home/robert/otel-tail-sampling

# Option A: Using gh CLI
gh repo create otel-tail-sampling --public --source=. --remote=origin --push

# Option B: Manual
# Create repo at https://github.com/new, then:
git remote add origin https://github.com/YOUR_USERNAME/otel-tail-sampling.git
git push -u origin main
```

### 5. Configure GitHub Secrets

Create service principal:
```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az ad sp create-for-rbac \
  --name "github-otel-deploy" \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP \
  --sdk-auth
```

Copy output and add to GitHub:
- Go to: `https://github.com/YOUR_USERNAME/otel-tail-sampling/settings/secrets/actions`
- Add `AZURE_CREDENTIALS` (entire JSON output)
- Add `AZURE_MONITOR_ENDPOINT` (from step 2)
- Add `APPLICATIONINSIGHTS_CONNECTION_STRING` (from step 2)

### 6. Deploy!

```bash
git push origin main
# Watch deployment at: https://github.com/YOUR_USERNAME/otel-tail-sampling/actions
```

---

## ✅ Verify It Works

```bash
APP_URL="https://${APP_SERVICE_NAME}.azurewebsites.net"

# Test health
curl $APP_URL:13133/

# Send test error trace
curl -X POST "$APP_URL:4318/v1/traces" \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "test"}}]},
      "scopeSpans": [{
        "spans": [{
          "traceId": "5b8efff798038103d269b633813fc60c",
          "spanId": "eee19b7ec3c1b174",
          "name": "test-error",
          "kind": 1,
          "startTimeUnixNano": "1633000000000000000",
          "endTimeUnixNano": "1633000001000000000",
          "status": {"code": 2, "message": "Test error"}
        }]
      }]
    }]
  }'

# Check Application Insights (wait 1-2 minutes)
# Azure Portal → Your App Insights → Transaction search
```

---

## 🔧 Configure Your App

Point your application's OTLP exporter to:
- **HTTP**: `http://${APP_SERVICE_NAME}.azurewebsites.net:4318`
- **gRPC**: `http://${APP_SERVICE_NAME}.azurewebsites.net:4317`

### .NET Example
```csharp
.AddOtlpExporter(options => {
    options.Endpoint = new Uri("http://otel-tail-sampling.azurewebsites.net:4318");
});
```

### Node.js Example
```javascript
const exporter = new OTLPTraceExporter({
  url: 'http://otel-tail-sampling.azurewebsites.net:4318/v1/traces'
});
```

### Python Example
```python
exporter = OTLPSpanExporter(
    endpoint="http://otel-tail-sampling.azurewebsites.net:4318/v1/traces"
)
```

---

## 📊 What You Get

- ✅ **100% of error traces** kept
- ✅ **100% of slow traces** (>5s) kept
- ✅ **10% of successful traces** sampled
- ✅ **~85-90% cost reduction** on Application Insights ingestion

---

## 📚 Full Documentation

- [Deployment Guide](docs/deployment-guide.md) - Detailed deployment steps
- [Application Integration](docs/app-integration.md) - How to configure your apps
- [README](README.md) - Full documentation

---

## 🛠️ Troubleshooting

### Traces not appearing?
```bash
# Check collector logs
az webapp log tail --name $APP_SERVICE_NAME --resource-group $RESOURCE_GROUP

# Check health
curl https://${APP_SERVICE_NAME}.azurewebsites.net:13133/
```

### Need help?
- Check the [README](README.md)
- Review [docs/deployment-guide.md](docs/deployment-guide.md)
- Check OpenTelemetry [tail sampling docs](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/processor/tailsamplingprocessor/README.md)
