# Azure Application Insights Tracing

How Azure handles distributed tracing and dependency tracking.

## Azure's Built-in Tracing

Azure Application Insights automatically tracks dependencies without code changes in many scenarios.

### Automatic Dependency Tracking

When you use the Application Insights SDK or Azure Monitor agent, these are tracked automatically:

**Outgoing HTTP calls:**
- HttpClient (.NET)
- RestSharp
- requests (Python)
- axios, fetch (Node.js)

**Database calls:**
- SQL Server, PostgreSQL, MySQL
- Entity Framework, Dapper
- MongoDB, Cosmos DB
- Redis Cache

**Azure Services:**
- Azure Storage (Blob, Queue, Table)
- Service Bus
- Event Hubs
- Cosmos DB

**Message Queues:**
- RabbitMQ
- Kafka

## Setup Examples

### .NET (Automatic Tracking)

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// Add Application Insights
builder.Services.AddApplicationInsightsTelemetry();

// That's it! No additional setup needed
var app = builder.Build();

// This is automatically tracked:
app.MapGet("/api/users/{id}", async (int id, HttpClient httpClient, AppDbContext db) =>
{
    // HTTP call - automatically tracked as dependency
    var user = await httpClient.GetFromJsonAsync<User>($"https://api.example.com/users/{id}");

    // Database call - automatically tracked as dependency
    var orders = await db.Orders.Where(o => o.UserId == id).ToListAsync();

    return new { user, orders };
});
```

**What you see in Application Insights:**
- Parent operation: `GET /api/users/{id}`
- Dependency 1: HTTP call to `api.example.com`
- Dependency 2: SQL query to database
- All with the same Operation ID (trace ID)

### Azure App Service (Zero Code)

If you deploy to Azure App Service:

```bash
# Enable Application Insights in Azure Portal
az webapp config appsettings set \
  --resource-group myRG \
  --name myApp \
  --settings APPLICATIONINSIGHTS_CONNECTION_STRING="<connection-string>"

# Or in Azure Portal:
# App Service → Application Insights → Enable
```

**Azure automatically injects the agent!** No code changes needed.

### Node.js (Auto-instrumentation)

```javascript
// index.js - MUST be at the very top
const appInsights = require('applicationinsights');
appInsights.setup('<instrumentation-key>')
    .setAutoDependencyCorrelation(true)
    .setAutoCollectRequests(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true)
    .setUseDiskRetryCaching(true)
    .start();

// Now all your code is automatically instrumented:
const express = require('express');
const axios = require('axios');
const redis = require('redis');

app.get('/api/data', async (req, res) => {
    // All of these are automatically tracked:

    // HTTP call
    const data = await axios.get('https://api.example.com/data');

    // Redis
    const cached = await redisClient.get('key');

    // Database
    const results = await db.query('SELECT * FROM users');

    res.json({ data, cached, results });
});
```

### Python (OpenCensus)

```python
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.ext.flask.flask_middleware import FlaskMiddleware
from opencensus.trace.samplers import AlwaysOnSampler

app = Flask(__name__)

# Setup auto-instrumentation
middleware = FlaskMiddleware(
    app,
    exporter=AzureExporter(
        connection_string='InstrumentationKey=xxx;IngestionEndpoint=https://xxx.in.applicationinsights.azure.com/'
    ),
    sampler=AlwaysOnSampler()
)

# Automatically tracks:
@app.route('/api/orders/<order_id>')
def get_order(order_id):
    # HTTP call - auto-tracked
    user = requests.get(f'https://api.example.com/users/{user_id}').json()

    # Database - auto-tracked
    order = db.session.query(Order).filter_by(id=order_id).first()

    # Redis - auto-tracked
    cache_key = f'order:{order_id}'
    cached = redis_client.get(cache_key)

    return jsonify(order)
```

## Azure's Correlation Headers

### Legacy Format (still supported):

```http
Request-Id: |KqKV7g73D40=.bcec871b_.1.
Request-Context: appId=cid-v1:73820a3c-6b4e-4329-b774-7f67f82cd9c9
```

### Modern Format (W3C Trace Context):

```http
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
tracestate: appId=cid-v1:73820a3c-6b4e-4329-b774-7f67f82cd9c9
Request-Id: |KqKV7g73D40=.bcec871b_.1.
```

Azure sends BOTH for backward compatibility!

## Viewing Traces in Azure Portal

### Application Map
```
Azure Portal → Application Insights → Application Map
```
Shows services and their dependencies visually.

### End-to-End Transaction
```
Azure Portal → Application Insights → Transaction search
→ Click a request → See full trace
```

Shows:
- Timeline of all operations
- Duration of each dependency
- SQL queries, HTTP calls, etc.
- Exceptions and logs correlated to the trace

### Performance Tab
```
Azure Portal → Application Insights → Performance
→ Operations → Select operation → Dependencies
```

Shows dependency breakdown and performance.

## Azure + OpenTelemetry

**Modern approach:** Use OpenTelemetry SDK with Azure Monitor exporter.

### .NET with OpenTelemetry

```csharp
using Azure.Monitor.OpenTelemetry.Exporter;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenTelemetry()
    .WithTracing(tracerProviderBuilder =>
    {
        tracerProviderBuilder
            .SetResourceBuilder(ResourceBuilder.CreateDefault()
                .AddService("my-service"))
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddSqlClientInstrumentation()
            // Send to BOTH Azure AND OTel Collector!
            .AddAzureMonitorTraceExporter(options =>
            {
                options.ConnectionString = "<app-insights-connection-string>";
            })
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri("http://otel-collector:4318");
            });
    });
```

This way you get:
- ✅ Data in Azure Application Insights
- ✅ Data in your OTel Collector (with tail sampling!)
- ✅ Data in Axiom
- ✅ Standard W3C trace context

### Node.js with OpenTelemetry

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { AzureMonitorTraceExporter } = require('@azure/monitor-opentelemetry-exporter');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const azureExporter = new AzureMonitorTraceExporter({
  connectionString: '<app-insights-connection-string>'
});

const otelExporter = new OTLPTraceExporter({
  url: 'http://otel-collector:4318/v1/traces'
});

const sdk = new NodeSDK({
  traceExporter: new MultiExporter([azureExporter, otelExporter]),
  instrumentations: [getNodeAutoInstrumentations()]
});

sdk.start();
```

## Comparison: Azure SDK vs OpenTelemetry

### Azure Application Insights SDK

**Pros:**
- ✅ Zero-config in Azure App Service
- ✅ Deep Azure service integration
- ✅ Automatic dependency tracking
- ✅ Rich Azure Portal visualizations
- ✅ Built-in sampling, filtering

**Cons:**
- ❌ Azure-specific (vendor lock-in)
- ❌ Less control over sampling
- ❌ Can't easily send to multiple backends

### OpenTelemetry with Azure Monitor Exporter

**Pros:**
- ✅ Vendor-neutral (works with any backend)
- ✅ Can send to multiple destinations
- ✅ Full control over sampling
- ✅ Standard W3C trace context
- ✅ Rich ecosystem

**Cons:**
- ⚠️ Requires more setup
- ⚠️ Some Azure-specific features may not work

## Best Practice: Hybrid Approach

Use OpenTelemetry SDK → Send to OTel Collector → Forward to both Axiom and Azure:

```yaml
# otel-collector-config.yaml
exporters:
  otlphttp/axiom:
    endpoint: "https://api.axiom.co"
    headers:
      Authorization: "Bearer ${AXIOM_API_TOKEN}"
      X-Axiom-Dataset: "${AXIOM_DATASET}"

  otlphttp/azure:
    endpoint: "${AZURE_MONITOR_ENDPOINT}"
    headers:
      # Azure connection string

pipelines:
  traces:
    receivers: [otlp]
    processors: [memory_limiter, tail_sampling, batch]
    exporters: [otlphttp/axiom, otlphttp/azure, logging]
```

This gives you:
- ✅ Tail sampling (cost savings)
- ✅ Data in Axiom (fast querying)
- ✅ Data in Azure (native Azure integrations)
- ✅ Vendor-neutral instrumentation

## Azure Function Apps

Azure Functions have built-in Application Insights integration:

```csharp
[Function("ProcessOrder")]
public async Task<HttpResponseData> Run(
    [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req,
    FunctionContext executionContext)
{
    var logger = executionContext.GetLogger("ProcessOrder");

    // Automatically tracked:
    logger.LogInformation("Processing order");

    // HTTP call - auto-tracked
    var user = await _httpClient.GetFromJsonAsync<User>("https://api.example.com/user");

    // Cosmos DB - auto-tracked
    await _cosmosClient.CreateDocumentAsync(order);

    // All correlated to the same trace!
    return req.CreateResponse(HttpStatusCode.OK);
}
```

**No additional setup needed** - just deploy and it works!

## Troubleshooting

### Traces not correlating?

Check these headers are being propagated:

```bash
# Should see:
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
Request-Id: |KqKV7g73D40=.bcec871b_.1.
```

### Missing dependencies?

Ensure auto-instrumentation is enabled:

```csharp
// .NET
services.AddApplicationInsightsTelemetry();

// Node.js
appInsights.setAutoDependencyCorrelation(true);

// Python
middleware = FlaskMiddleware(app, exporter=AzureExporter(...))
```

### Want both Azure and OTel?

Use composite exporters or the collector pattern shown above.
