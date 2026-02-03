# Trace Context Propagation

How to chain traces across multiple services so they appear as one distributed trace.

## The Problem

```
Service A → Service B → Service C → Database
  ❌ Without propagation: 3 separate traces (can't see the full flow)
  ✅ With propagation: 1 unified trace with parent-child relationships
```

## The Solution: W3C Trace Context

Services pass trace context via HTTP headers:

```http
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
             │  │                                │                │
             │  └─ Trace ID (shared)            └─ Parent Span   └─ Sampled flag
             └─ Version
```

## Implementation Examples

### .NET / C# (Service A → Service B)

**Service A (API Gateway):**

```csharp
using OpenTelemetry;
using OpenTelemetry.Trace;
using System.Net.Http;

public class ApiGatewayController : ControllerBase
{
    private readonly IHttpClientFactory _httpClientFactory;

    [HttpPost("/api/orders")]
    public async Task<IActionResult> CreateOrder([FromBody] Order order)
    {
        // OpenTelemetry automatically creates a span for this HTTP request
        using var activity = Activity.Current;
        activity?.SetTag("order.id", order.Id);

        // Call Service B
        var client = _httpClientFactory.CreateClient("OrderService");

        // OpenTelemetry instrumentation automatically injects traceparent header!
        var response = await client.PostAsJsonAsync("/process", order);

        return Ok(response);
    }
}

// Startup.cs configuration:
services.AddOpenTelemetry()
    .WithTracing(tracerProviderBuilder =>
    {
        tracerProviderBuilder
            .AddAspNetCoreInstrumentation()  // Incoming requests
            .AddHttpClientInstrumentation()  // Outgoing requests (auto-propagates!)
            .AddOtlpExporter(options => {
                options.Endpoint = new Uri("http://otel-collector:4318");
            });
    });
```

**Service B (Order Service):**

```csharp
public class OrderServiceController : ControllerBase
{
    private readonly DatabaseContext _db;

    [HttpPost("/process")]
    public async Task<IActionResult> ProcessOrder([FromBody] Order order)
    {
        // OpenTelemetry automatically extracts traceparent header
        // and creates a child span under Service A's span!

        using var activity = Activity.Current;
        activity?.SetTag("order.items", order.Items.Count);

        // Database call - automatically traced as child span
        await _db.Orders.AddAsync(order);
        await _db.SaveChangesAsync();

        // Call Service C
        var client = _httpClientFactory.CreateClient("PaymentService");
        var payment = await client.PostAsJsonAsync("/charge", new {
            orderId = order.Id,
            amount = order.Total
        });

        return Ok();
    }
}
```

### Node.js / TypeScript (Service A → Service B)

**Service A:**

```typescript
import { trace, context, propagation } from '@opentelemetry/api';
import axios from 'axios';

app.post('/api/orders', async (req, res) => {
  const tracer = trace.getTracer('api-gateway');

  await tracer.startActiveSpan('create_order', async (span) => {
    span.setAttribute('order.id', req.body.orderId);

    // Call Service B
    // Axios interceptor automatically injects trace context!
    const response = await axios.post('http://order-service/process', req.body);

    span.end();
    res.json(response.data);
  });
});

// Setup with auto-instrumentation:
const sdk = new NodeSDK({
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': {
        // Automatically propagates trace context
        requestHook: (span, request) => {
          span.setAttribute('http.method', request.method);
        }
      }
    })
  ],
  traceExporter: new OTLPTraceExporter({
    url: 'http://otel-collector:4318/v1/traces'
  })
});
```

**Service B:**

```typescript
app.post('/process', async (req, res) => {
  const tracer = trace.getTracer('order-service');

  // OpenTelemetry automatically extracts trace context from headers
  // This span will be a child of Service A's span!

  await tracer.startActiveSpan('process_order', async (span) => {
    span.setAttribute('order.total', req.body.total);

    // Database call (automatically traced)
    await db.orders.insert(req.body);

    // Call Service C
    await axios.post('http://payment-service/charge', {
      orderId: req.body.orderId,
      amount: req.body.total
    });

    span.end();
    res.json({ success: true });
  });
});
```

### Python (Service A → Service B)

**Service A:**

```python
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
import requests

tracer = trace.get_tracer(__name__)

@app.route('/api/orders', methods=['POST'])
def create_order():
    with tracer.start_as_current_span("create_order") as span:
        order = request.get_json()
        span.set_attribute("order.id", order['id'])

        # Requests library automatically propagates trace context!
        response = requests.post(
            'http://order-service/process',
            json=order
        )

        return jsonify(response.json())

# Setup:
FlaskInstrumentor().instrument_app(app)  # Incoming requests
RequestsInstrumentor().instrument()      # Outgoing requests (auto-propagates!)
```

**Service B:**

```python
@app.route('/process', methods=['POST'])
def process_order():
    # Trace context automatically extracted from headers!
    # This span is a child of Service A's span

    with tracer.start_as_current_span("process_order") as span:
        order = request.get_json()
        span.set_attribute("order.total", order['total'])

        # Database call
        db.session.add(Order(**order))
        db.session.commit()

        # Call Service C
        response = requests.post(
            'http://payment-service/charge',
            json={'order_id': order['id'], 'amount': order['total']}
        )

        return jsonify({'success': True})
```

## Manual Propagation (if not using auto-instrumentation)

If you're not using OpenTelemetry SDKs or need manual control:

### Service A (Creating and Injecting Context):

```typescript
import { propagation, trace, context } from '@opentelemetry/api';

const span = tracer.startSpan('call_service_b');
const ctx = trace.setSpan(context.active(), span);

// Manually inject trace context into headers
const headers = {};
propagation.inject(ctx, headers);

// headers now contains:
// {
//   "traceparent": "00-<trace-id>-<span-id>-01"
// }

await fetch('http://service-b/api', {
  method: 'POST',
  headers: headers,
  body: JSON.stringify(data)
});

span.end();
```

### Service B (Extracting Context):

```typescript
app.post('/api', (req, res) => {
  // Extract trace context from incoming headers
  const ctx = propagation.extract(context.active(), req.headers);

  // Create span as child of extracted context
  const span = tracer.startSpan(
    'handle_request',
    { parent: trace.getSpan(ctx) }
  );

  // ... do work ...

  span.end();
  res.json({ success: true });
});
```

## Testing Trace Propagation

### Test Script (simulating Service A → B → C):

```bash
#!/bin/bash

TRACE_ID=$(uuidgen | tr -d '-' | cut -c1-32)

# Service A span
SPAN_A_ID=$(uuidgen | tr -d '-' | cut -c1-16)

# Service B span (child of A)
SPAN_B_ID=$(uuidgen | tr -d '-' | cut -c1-16)

# Service C span (child of B)
SPAN_C_ID=$(uuidgen | tr -d '-' | cut -c1-16)

# Send all spans with same trace ID and proper parent relationships
curl -X POST "http://localhost:4318/v1/traces" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [
      {
        \"resource\": {
          \"attributes\": [{\"key\": \"service.name\", \"value\": {\"stringValue\": \"service-a\"}}]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$SPAN_A_ID\",
            \"name\": \"POST /api/orders\",
            \"kind\": 1,
            \"startTimeUnixNano\": \"$(date +%s%N)\",
            \"endTimeUnixNano\": \"$(($(date +%s%N) + 100000000))\",
            \"status\": {\"code\": 1}
          }]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [{\"key\": \"service.name\", \"value\": {\"stringValue\": \"service-b\"}}]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$SPAN_B_ID\",
            \"parentSpanId\": \"$SPAN_A_ID\",  ← Links to Service A
            \"name\": \"process_order\",
            \"kind\": 3,
            \"startTimeUnixNano\": \"$(($(date +%s%N) + 10000000))\",
            \"endTimeUnixNano\": \"$(($(date +%s%N) + 80000000))\",
            \"status\": {\"code\": 1}
          }]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [{\"key\": \"service.name\", \"value\": {\"stringValue\": \"service-c\"}}]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$SPAN_C_ID\",
            \"parentSpanId\": \"$SPAN_B_ID\",  ← Links to Service B
            \"name\": \"SELECT orders\",
            \"kind\": 3,
            \"startTimeUnixNano\": \"$(($(date +%s%N) + 20000000))\",
            \"endTimeUnixNano\": \"$(($(date +%s%N) + 60000000))\",
            \"attributes\": [{\"key\": \"db.system\", \"value\": {\"stringValue\": \"postgresql\"}}],
            \"status\": {\"code\": 1}
          }]
        }]
      }
    ]
  }"
```

## Key Principles

1. **Same Trace ID** - All spans in a distributed trace share the same trace ID
2. **Parent Span ID** - Each child span references its parent's span ID
3. **Automatic Propagation** - OpenTelemetry SDKs handle this automatically
4. **W3C Standard** - Uses standard `traceparent` header format
5. **Context Propagation** - Works across HTTP, gRPC, messaging queues, etc.

## Common Pitfalls

### ❌ Not instrumenting HTTP clients

```csharp
// This won't propagate trace context!
var client = new HttpClient();
await client.GetAsync("http://service-b");
```

```csharp
// This will! ✓
services.AddHttpClient()
    .AddOpenTelemetry(); // or use AddHttpClientInstrumentation()
```

### ❌ Creating new trace ID for each service

```typescript
// Wrong - creates separate traces
const span = tracer.startSpan('my_span');  // New trace!
```

```typescript
// Right - continues existing trace
const span = tracer.startSpan('my_span', {
  parent: trace.getSpan(context.active())  // Continues trace
});
```

### ❌ Not extracting context from headers

```python
# Wrong - ignores incoming trace context
@app.route('/api')
def handler():
    with tracer.start_as_current_span("handler"):  # Creates new trace!
        pass
```

```python
# Right - FlaskInstrumentor automatically extracts context
FlaskInstrumentor().instrument_app(app)

@app.route('/api')
def handler():
    # Context automatically extracted from headers
    with tracer.start_as_current_span("handler"):  # Continues trace!
        pass
```

## Viewing Propagated Traces in Axiom

When properly propagated, you'll see:

1. **Service Map** - Visual graph showing Service A → B → C
2. **Trace Timeline** - Waterfall showing all spans chronologically
3. **Span Tree** - Hierarchical view of parent-child relationships
4. **Single Trace ID** - All spans grouped under one trace

Look for attributes:
- `trace.id` - Same across all services
- `span.parent_id` - Links spans together
- `service.name` - Different for each service
