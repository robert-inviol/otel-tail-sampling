# OpenTelemetry Tail Sampling Collector

This project provides an OpenTelemetry Collector configured with tail-based sampling for Azure App Service deployment. It keeps all error traces while sampling successful traces, optimizing observability costs.

## Features

- **Tail-based sampling**: Intelligent sampling decisions after seeing complete traces
- **Keep all errors**: 100% retention of traces with ERROR status codes
- **Keep slow traces**: 100% retention of traces exceeding latency threshold (5s)
- **Sample successes**: 10% sampling of normal/successful traces
- **Azure integration**: Ready for Azure Application Insights
- **Docker-ready**: Containerized for easy deployment
- **CI/CD**: GitHub Actions pipeline for automated deployment

## Architecture

```
Application → OTLP → OTel Collector (Tail Sampling) → Azure Monitor
                          ↓
                   Sampling Policies:
                   - ERROR status: 100%
                   - Latency >5s: 100%
                   - Success: 10%
```

## Quick Start

### Local Development

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url>
   cd otel-tail-sampling
   ```

2. **Set environment variables**:
   ```bash
   export APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=xxx;IngestionEndpoint=https://xxx.in.applicationinsights.azure.com/"
   export AZURE_MONITOR_ENDPOINT="https://your-workspace.in.applicationinsights.azure.com/v2.1/track"
   ```

3. **Run with Docker Compose**:
   ```bash
   docker-compose up -d
   ```

4. **Test the collector**:
   ```bash
   # Check health
   curl http://localhost:13133/

   # View metrics
   curl http://localhost:8888/metrics
   ```

### Deploy to Azure App Service

#### Prerequisites

1. **Azure App Service** (Linux, Container)
2. **Azure Application Insights** workspace
3. **GitHub repository** with this code

#### Setup Steps

1. **Create Azure App Service**:
   ```bash
   az group create --name otel-rg --location eastus

   az appservice plan create \
     --name otel-plan \
     --resource-group otel-rg \
     --is-linux \
     --sku B1

   az webapp create \
     --resource-group otel-rg \
     --plan otel-plan \
     --name otel-tail-sampling \
     --deployment-container-image-name otel/opentelemetry-collector-contrib:latest
   ```

2. **Configure GitHub Secrets**:

   Go to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

   Add these secrets:
   - `AZURE_CREDENTIALS`: Service principal credentials (JSON format)
   - `AZURE_MONITOR_ENDPOINT`: Application Insights endpoint
   - `APPLICATIONINSIGHTS_CONNECTION_STRING`: App Insights connection string

   To create service principal:
   ```bash
   az ad sp create-for-rbac \
     --name "github-otel-deploy" \
     --role contributor \
     --scopes /subscriptions/{subscription-id}/resourceGroups/otel-rg \
     --sdk-auth
   ```

3. **Update workflow file**:

   Edit `.github/workflows/deploy.yml` and replace:
   - `AZURE_WEBAPP_NAME` with your App Service name

4. **Push to GitHub**:
   ```bash
   git add .
   git commit -m "Initial commit"
   git push origin main
   ```

   The GitHub Action will automatically build and deploy.

## Configuration

### Sampling Policies

Edit `otel-collector-config.yaml` to customize sampling:

```yaml
policies:
  # Keep all errors
  - name: error-traces
    type: status_code
    status_code:
      status_codes:
        - ERROR

  # Keep slow traces (>5 seconds)
  - name: slow-traces
    type: latency
    latency:
      threshold_ms: 5000

  # Sample 10% of normal traces
  - name: probabilistic-sample
    type: probabilistic
    probabilistic:
      sampling_percentage: 10
```

### Memory Configuration

Adjust memory limits in `otel-collector-config.yaml`:

```yaml
memory_limiter:
  limit_mib: 2048        # Maximum memory
  spike_limit_mib: 512   # Spike limit
```

For Azure App Service, ensure your App Service Plan has sufficient memory (recommended: 4GB+).

## Monitoring

### Health Check

```bash
curl http://<your-app>.azurewebsites.net:13133/
```

### Metrics

```bash
curl http://<your-app>.azurewebsites.net:8888/metrics
```

### Collector Logs

View in Azure Portal:
1. Go to App Service → Monitoring → Log stream
2. Or use: `az webapp log tail --name otel-tail-sampling --resource-group otel-rg`

## Application Integration

Configure your applications to send OTLP data to the collector:

### .NET Example

```csharp
services.AddOpenTelemetry()
    .WithTracing(builder => builder
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri("http://otel-tail-sampling.azurewebsites.net:4318");
            options.Protocol = OtlpExportProtocol.HttpProtobuf;
        }));
```

### Node.js Example

```javascript
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const exporter = new OTLPTraceExporter({
  url: 'http://otel-tail-sampling.azurewebsites.net:4318/v1/traces'
});
```

### Python Example

```python
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor

exporter = OTLPSpanExporter(
    endpoint="http://otel-tail-sampling.azurewebsites.net:4318/v1/traces"
)
```

## Troubleshooting

### No traces appearing

1. Check collector logs: `az webapp log tail`
2. Verify Application Insights connection string
3. Test health endpoint: `curl http://<app>.azurewebsites.net:13133/`
4. Check App Service ports are correctly configured (4317, 4318)

### High memory usage

1. Reduce `num_traces` in config
2. Decrease `decision_wait` time
3. Increase sampling percentage to reduce trace retention
4. Upgrade App Service Plan

### Sampling not working as expected

1. Ensure all spans of a trace reach the same collector instance
2. Check `decision_wait` is sufficient for your trace duration
3. Verify policy configuration in logs

## Cost Optimization

This configuration reduces Azure Monitor ingestion costs by:
- Keeping 100% of error traces (most valuable)
- Keeping 100% of slow traces (performance issues)
- Sampling only 10% of successful traces

Estimated reduction: ~85% fewer traces ingested while maintaining full error visibility.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License

## Resources

- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Tail Sampling Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/processor/tailsamplingprocessor/README.md)
- [Azure Application Insights](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Azure App Service Containers](https://docs.microsoft.com/azure/app-service/configure-custom-container)
