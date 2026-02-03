#!/bin/bash

# Simulate REAL distributed tracing - each service sends separately
COLLECTOR_URL="${1:-http://localhost:4318}"

echo "🌐 Simulating REALISTIC distributed trace..."
echo "   (Each service sends its spans independently)"
echo ""

TRACE_ID=$(uuidgen | tr -d '-' | cut -c1-32)
NOW=$(date +%s%N)

# Service A span IDs
GATEWAY_SPAN=$(uuidgen | tr -d '-' | cut -c1-16)
# Service B span IDs
ORDER_SPAN=$(uuidgen | tr -d '-' | cut -c1-16)
DB_SPAN=$(uuidgen | tr -d '-' | cut -c1-16)
# Service C span IDs
PAYMENT_SPAN=$(uuidgen | tr -d '-' | cut -c1-16)

echo "Trace ID: $TRACE_ID"
echo ""

# Service A sends first (t=0)
echo "[Service A] api-gateway sending span..."
curl -s -X POST "$COLLECTOR_URL/v1/traces" -H "Content-Type: application/json" -d "{
  \"resourceSpans\": [{
    \"resource\": {
      \"attributes\": [
        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"REALISTIC-GATEWAY\"}}
      ]
    },
    \"scopeSpans\": [{
      \"spans\": [{
        \"traceId\": \"$TRACE_ID\",
        \"spanId\": \"$GATEWAY_SPAN\",
        \"name\": \"POST /api/checkout\",
        \"kind\": 1,
        \"startTimeUnixNano\": \"$NOW\",
        \"endTimeUnixNano\": \"$((NOW + 200000000))\",
        \"attributes\": [{\"key\": \"http.status_code\", \"value\": {\"intValue\": \"200\"}}],
        \"status\": {\"code\": 1}
      }]
    }]
  }]
}" > /dev/null
echo "  ✓ Sent (1 span)"

sleep 0.5

# Service B sends next (t=0.5s)
echo "[Service B] order-service sending spans..."
curl -s -X POST "$COLLECTOR_URL/v1/traces" -H "Content-Type: application/json" -d "{
  \"resourceSpans\": [{
    \"resource\": {
      \"attributes\": [
        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"REALISTIC-ORDER\"}}
      ]
    },
    \"scopeSpans\": [{
      \"spans\": [
        {
          \"traceId\": \"$TRACE_ID\",
          \"spanId\": \"$ORDER_SPAN\",
          \"parentSpanId\": \"$GATEWAY_SPAN\",
          \"name\": \"create_order\",
          \"kind\": 3,
          \"startTimeUnixNano\": \"$((NOW + 10000000))\",
          \"endTimeUnixNano\": \"$((NOW + 150000000))\",
          \"status\": {\"code\": 1}
        },
        {
          \"traceId\": \"$TRACE_ID\",
          \"spanId\": \"$DB_SPAN\",
          \"parentSpanId\": \"$ORDER_SPAN\",
          \"name\": \"INSERT INTO orders\",
          \"kind\": 3,
          \"startTimeUnixNano\": \"$((NOW + 20000000))\",
          \"endTimeUnixNano\": \"$((NOW + 80000000))\",
          \"attributes\": [{\"key\": \"db.system\", \"value\": {\"stringValue\": \"postgresql\"}}],
          \"status\": {\"code\": 1}
        }
      ]
    }]
  }]
}" > /dev/null
echo "  ✓ Sent (2 spans)"

sleep 0.5

# Service C sends last (t=1s)
echo "[Service C] payment-service sending span..."
curl -s -X POST "$COLLECTOR_URL/v1/traces" -H "Content-Type: application/json" -d "{
  \"resourceSpans\": [{
    \"resource\": {
      \"attributes\": [
        {\"key\": \"service.name\", \"value\": {\"stringValue\": \"REALISTIC-PAYMENT\"}}
      ]
    },
    \"scopeSpans\": [{
      \"spans\": [{
        \"traceId\": \"$TRACE_ID\",
        \"spanId\": \"$PAYMENT_SPAN\",
        \"parentSpanId\": \"$ORDER_SPAN\",
        \"name\": \"process_payment\",
        \"kind\": 3,
        \"startTimeUnixNano\": \"$((NOW + 160000000))\",
        \"endTimeUnixNano\": \"$((NOW + 195000000))\",
        \"attributes\": [{\"key\": \"payment.amount\", \"value\": {\"doubleValue\": 99.99}}],
        \"status\": {\"code\": 2, \"message\": \"Payment declined - ERROR for 100% sampling\"}
      }]
    }]
  }]
}" > /dev/null
echo "  ✓ Sent (1 span)"

echo ""
echo "✅ Sent realistic distributed trace!"
echo ""
echo "📊 Summary:"
echo "   Trace ID: $TRACE_ID"
echo "   Services: 3 (sent separately, like real microservices)"
echo "   Total spans: 4"
echo "   Sent over: 1 second"
echo "   Has ERROR: Yes (payment declined) → 100% sampling"
echo ""
echo "⏰ Tail sampling will wait 10s to collect all spans..."
echo "   Then export them together to Axiom"
echo ""
echo "🔍 Search Axiom in 15s for:"
echo "   • Trace ID: $TRACE_ID"
echo "   • service.name: REALISTIC-GATEWAY, REALISTIC-ORDER, REALISTIC-PAYMENT"
echo "   • You should see all 4 spans linked together!"
