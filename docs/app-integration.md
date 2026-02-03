# Application Integration Guide

## Step 1: Get Azure Application Insights Connection Info

```bash
# Get your Application Insights connection string
az monitor app-insights component show \
  --app your-app-insights-name \
  --resource-group your-rg \
  --query connectionString -o tsv
```

You need:
- **Connection String**: `InstrumentationKey=xxx;IngestionEndpoint=https://xxx.in.applicationinsights.azure.com/`
- **Endpoint**: `https://xxx.in.applicationinsights.azure.com/v2.1/track`

## Step 2: Configure Your Application

### .NET / C# Application

**Install packages:**
```bash
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
```

**Configure in Program.cs:**
```csharp
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

// Add OpenTelemetry
builder.Services.AddOpenTelemetry()
    .WithTracing(tracerProviderBuilder =>
    {
        tracerProviderBuilder
            .AddSource("YourServiceName")
            .SetResourceBuilder(ResourceBuilder.CreateDefault()
                .AddService("YourServiceName"))
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddOtlpExporter(options =>
            {
                // Point to your OTel Collector
                options.Endpoint = new Uri("http://otel-tail-sampling.azurewebsites.net:4318");
                options.Protocol = OtlpExportProtocol.HttpProtobuf;
            });
    });

var app = builder.Build();
```

**appsettings.json:**
```json
{
  "OpenTelemetry": {
    "Otlp": {
      "Endpoint": "http://otel-tail-sampling.azurewebsites.net:4318"
    }
  }
}
```

### Node.js / TypeScript Application

**Install packages:**
```bash
npm install @opentelemetry/api \
            @opentelemetry/sdk-node \
            @opentelemetry/auto-instrumentations-node \
            @opentelemetry/exporter-trace-otlp-http
```

**Create tracing.js:**
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const traceExporter = new OTLPTraceExporter({
  url: 'http://otel-tail-sampling.azurewebsites.net:4318/v1/traces',
});

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'your-service-name',
  }),
  traceExporter,
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('Tracing terminated'))
    .catch((error) => console.log('Error terminating tracing', error))
    .finally(() => process.exit(0));
});
```

**Run your app:**
```bash
node -r ./tracing.js app.js
```

### Python Application

**Install packages:**
```bash
pip install opentelemetry-api \
            opentelemetry-sdk \
            opentelemetry-exporter-otlp-proto-http \
            opentelemetry-instrumentation-flask
```

**Configure in your app:**
```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

# Configure resource
resource = Resource.create({"service.name": "your-service-name"})

# Set up tracer provider
trace.set_tracer_provider(TracerProvider(resource=resource))

# Configure OTLP exporter
otlp_exporter = OTLPSpanExporter(
    endpoint="http://otel-tail-sampling.azurewebsites.net:4318/v1/traces"
)

# Add span processor
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)

# Get tracer
tracer = trace.get_tracer(__name__)

# Use in your app
@app.route('/')
def hello():
    with tracer.start_as_current_span("hello-request"):
        return "Hello World"
```

### Java / Spring Boot Application

**Add Maven dependency (pom.xml):**
```xml
<dependencies>
    <dependency>
        <groupId>io.opentelemetry</groupId>
        <artifactId>opentelemetry-api</artifactId>
    </dependency>
    <dependency>
        <groupId>io.opentelemetry</groupId>
        <artifactId>opentelemetry-sdk</artifactId>
    </dependency>
    <dependency>
        <groupId>io.opentelemetry</groupId>
        <artifactId>opentelemetry-exporter-otlp</artifactId>
    </dependency>
</dependencies>
```

**Configure in application.properties:**
```properties
otel.service.name=your-service-name
otel.traces.exporter=otlp
otel.exporter.otlp.endpoint=http://otel-tail-sampling.azurewebsites.net:4318
otel.exporter.otlp.protocol=http/protobuf
```

**Or use Java agent:**
```bash
java -javaagent:opentelemetry-javaagent.jar \
     -Dotel.service.name=your-service \
     -Dotel.exporter.otlp.endpoint=http://otel-tail-sampling.azurewebsites.net:4318 \
     -jar your-app.jar
```

## Step 3: Test Your Integration

### Send a test trace:
```bash
curl -X POST "http://otel-tail-sampling.azurewebsites.net:4318/v1/traces" \
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
          "name": "test-operation",
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
```

### Check Azure Application Insights:
1. Go to Azure Portal
2. Navigate to your Application Insights resource
3. Click "Transaction search" or "Application map"
4. Look for your test traces

## Step 4: Verify Sampling

**What you should see:**
- ✅ ALL error traces appear in Application Insights
- ✅ ALL slow traces (>5s) appear in Application Insights
- ✅ Only ~10% of successful traces appear

**To verify:**
1. Generate 100 successful requests
2. Generate 10 error requests
3. In Application Insights, you should see:
   - ~10 successful traces (10% sampling)
   - All 10 error traces (100% kept)

## Troubleshooting

### Traces not appearing?

1. **Check collector logs:**
   ```bash
   az webapp log tail --name otel-tail-sampling --resource-group otel-rg
   ```

2. **Verify collector is running:**
   ```bash
   curl http://otel-tail-sampling.azurewebsites.net:13133/
   ```

3. **Check Application Insights connection:**
   - Verify `APPLICATIONINSIGHTS_CONNECTION_STRING` is set
   - Verify `AZURE_MONITOR_ENDPOINT` is correct

4. **Network connectivity:**
   - Ensure your app can reach the collector
   - Check firewall rules on Azure App Service
   - Verify ports 4317/4318 are accessible

### High memory usage?

Reduce these values in `otel-collector-config.yaml`:
```yaml
tail_sampling:
  num_traces: 50000              # Reduce from 100000
  decision_wait: 5s               # Reduce from 10s
  expected_new_traces_per_sec: 50 # Reduce from 100
```

### Not sampling as expected?

- Check trace status codes are being set correctly in your app
- Verify all spans of a trace have the same trace ID
- Ensure `decision_wait` is long enough for all spans to arrive
