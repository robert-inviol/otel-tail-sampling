# Authentication Setup

The OTel collector now requires **Bearer token authentication** for all incoming requests.

## 🔐 Security Overview

**Before authentication:**
- ❌ Anyone with the URL could send traces
- ❌ No protection against abuse
- ❌ Exposed to credential stuffing attacks

**With authentication:**
- ✅ Only authorized clients can send traces
- ✅ Token-based access control
- ✅ Protected endpoints

## 🔧 Configuration

### 1. Generate API Key

Generate a strong random token:

```bash
# Linux/Mac
openssl rand -hex 32

# Or use this
cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1

# Example output:
# a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
```

Save this token securely!

### 2. Set Environment Variable in Azure

```bash
RESOURCE_GROUP="otel-rg"
APP_SERVICE_NAME="otel-tail-sampling"
API_KEY="your-generated-token-here"

# Add the API key to Azure App Service
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $APP_SERVICE_NAME \
  --settings OTEL_API_KEY="$API_KEY"

# Restart to apply
az webapp restart \
  --resource-group $RESOURCE_GROUP \
  --name $APP_SERVICE_NAME
```

### 3. Add to GitHub Secrets

For CI/CD deployment, add `OTEL_API_KEY` as a GitHub secret:

1. Go to: `https://github.com/YOUR_USERNAME/otel-tail-sampling/settings/secrets/actions`
2. Click "New repository secret"
3. Name: `OTEL_API_KEY`
4. Value: Your generated token
5. Click "Add secret"

### 4. Update Local .env

For local testing:

```bash
echo "OTEL_API_KEY=your-generated-token-here" >> .env
```

## 📱 How to Use (Client Side)

Now your applications must include the Bearer token in all requests.

### .NET / C# Configuration

```csharp
using OpenTelemetry.Exporter;

builder.Services.AddOpenTelemetry()
    .WithTracing(tracerProviderBuilder =>
    {
        tracerProviderBuilder
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri("http://otel-tail-sampling.azurewebsites.net:4318");
                options.Protocol = OtlpExportProtocol.HttpProtobuf;

                // Add Bearer token authentication
                options.Headers = "Authorization=Bearer your-api-key-here";
            });
    });
```

**Using environment variable (recommended):**

```csharp
options.Headers = $"Authorization=Bearer {Environment.GetEnvironmentVariable("OTEL_API_KEY")}";
```

### Node.js / TypeScript Configuration

```javascript
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const exporter = new OTLPTraceExporter({
  url: 'http://otel-tail-sampling.azurewebsites.net:4318/v1/traces',
  headers: {
    'Authorization': `Bearer ${process.env.OTEL_API_KEY}`
  }
});
```

### Python Configuration

```python
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
import os

otlp_exporter = OTLPSpanExporter(
    endpoint="http://otel-tail-sampling.azurewebsites.net:4318/v1/traces",
    headers={
        "Authorization": f"Bearer {os.getenv('OTEL_API_KEY')}"
    }
)
```

### Java Configuration

**application.properties:**
```properties
otel.exporter.otlp.endpoint=http://otel-tail-sampling.azurewebsites.net:4318
otel.exporter.otlp.headers=Authorization=Bearer ${OTEL_API_KEY}
```

**Or with Java agent:**
```bash
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.exporter.otlp.endpoint=http://otel-tail-sampling.azurewebsites.net:4318 \
     -Dotel.exporter.otlp.headers="Authorization=Bearer ${OTEL_API_KEY}" \
     -jar your-app.jar
```

### cURL Test

```bash
# Set your API key
export OTEL_API_KEY="your-api-key-here"

# Test with authentication
curl -X POST "http://otel-tail-sampling.azurewebsites.net:4318/v1/traces" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OTEL_API_KEY" \
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
          "name": "test-operation",
          "kind": 1,
          "startTimeUnixNano": "1633000000000000000",
          "endTimeUnixNano": "1633000001000000000",
          "status": {"code": 2}
        }]
      }]
    }]
  }'
```

**Without authentication (will fail with 401):**
```bash
curl -X POST "http://otel-tail-sampling.azurewebsites.net:4318/v1/traces" \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans": [...]}'
# Response: 401 Unauthorized
```

## 🔄 Rotating API Keys

To rotate the API key:

1. **Generate new key:**
   ```bash
   NEW_API_KEY=$(openssl rand -hex 32)
   echo "New API Key: $NEW_API_KEY"
   ```

2. **Update Azure (but keep old key temporarily):**
   ```bash
   # You might want to support both keys during transition
   # This requires custom code - bearertokenauth only supports one token
   ```

3. **Update all applications with new key**

4. **Monitor logs** to ensure no 401 errors

5. **Remove old key** once all apps are updated

## 🛡️ Best Practices

### 1. Store Keys Securely

**DO:**
- ✅ Use Azure Key Vault for production
- ✅ Use environment variables
- ✅ Use CI/CD secret management
- ✅ Rotate keys regularly (every 90 days)

**DON'T:**
- ❌ Hard-code keys in source code
- ❌ Commit keys to Git
- ❌ Share keys via email/chat
- ❌ Use the same key across environments

### 2. Use Different Keys per Environment

```bash
# Development
OTEL_API_KEY_DEV="dev-key-here"

# Staging
OTEL_API_KEY_STAGING="staging-key-here"

# Production
OTEL_API_KEY_PROD="prod-key-here"
```

### 3. Azure Key Vault Integration (Advanced)

```bash
# Create Key Vault
az keyvault create \
  --name otel-keyvault \
  --resource-group otel-rg \
  --location eastus

# Store API key
az keyvault secret set \
  --vault-name otel-keyvault \
  --name OTEL-API-KEY \
  --value "your-api-key-here"

# Grant App Service access
APP_IDENTITY=$(az webapp identity assign \
  --resource-group otel-rg \
  --name otel-tail-sampling \
  --query principalId -o tsv)

az keyvault set-policy \
  --name otel-keyvault \
  --object-id $APP_IDENTITY \
  --secret-permissions get

# Reference in App Service
az webapp config appsettings set \
  --resource-group otel-rg \
  --name otel-tail-sampling \
  --settings OTEL_API_KEY="@Microsoft.KeyVault(SecretUri=https://otel-keyvault.vault.azure.net/secrets/OTEL-API-KEY/)"
```

## 🚨 Troubleshooting

### 401 Unauthorized Errors

**Check:**
1. Token is set correctly in environment variable
2. Token matches on both sides (client and server)
3. No extra whitespace in the token
4. Authorization header format is correct: `Bearer <token>`

**Debug:**
```bash
# Check Azure App Service settings
az webapp config appsettings list \
  --resource-group otel-rg \
  --name otel-tail-sampling \
  --query "[?name=='OTEL_API_KEY']"

# Check collector logs
az webapp log tail --name otel-tail-sampling --resource-group otel-rg
```

### Collector Not Starting

If the collector fails to start after adding authentication:

```bash
# Check logs
az webapp log tail --name otel-tail-sampling --resource-group otel-rg

# Verify OTEL_API_KEY is set
az webapp config appsettings list \
  --resource-group otel-rg \
  --name otel-tail-sampling
```

Common issues:
- `OTEL_API_KEY` environment variable not set
- Invalid YAML syntax in config file
- Extension not listed in `service.extensions`

### Testing Authentication Locally

```bash
# Start collector with API key
export OTEL_API_KEY="test-key-12345"
docker-compose up

# Test with correct key
curl -H "Authorization: Bearer test-key-12345" \
  http://localhost:4318/v1/traces

# Test with wrong key (should fail)
curl -H "Authorization: Bearer wrong-key" \
  http://localhost:4318/v1/traces
# Expected: 401 Unauthorized
```

## 🔐 Alternative: Mutual TLS (mTLS)

For even stronger security, consider mutual TLS authentication:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        tls:
          cert_file: /path/to/server.crt
          key_file: /path/to/server.key
          client_ca_file: /path/to/client-ca.crt
      http:
        endpoint: 0.0.0.0:4318
        tls:
          cert_file: /path/to/server.crt
          key_file: /path/to/server.key
          client_ca_file: /path/to/client-ca.crt
```

This requires:
- Certificate management
- Client certificates on all applications
- More complex setup

## 📚 Additional Resources

- [OpenTelemetry Collector Auth Extension](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/bearertokenauthextension)
- [OTLP Exporter Configuration](https://opentelemetry.io/docs/specs/otel/protocol/exporter/)
- [Azure Key Vault Best Practices](https://docs.microsoft.com/azure/key-vault/general/best-practices)
