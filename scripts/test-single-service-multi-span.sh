#!/bin/bash

# Send a multi-span trace from a SINGLE service (not distributed)
# This tests if the issue is with multiple resourceSpans

COLLECTOR_URL="${1:-http://localhost:4318}"

echo "🔍 Sending multi-span trace from SINGLE service..."

TRACE_ID=$(uuidgen | tr -d '-' | cut -c1-32)
NOW=$(date +%s%N)

# All spans from same service, same resource
SPAN1=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN2=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN3=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN4=$(uuidgen | tr -d '-' | cut -c1-16)

curl -X POST "$COLLECTOR_URL/v1/traces" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [{
      \"resource\": {
        \"attributes\": [
          {\"key\": \"service.name\", \"value\": {\"stringValue\": \"MULTI-SPAN-TEST-SERVICE\"}},
          {\"key\": \"service.version\", \"value\": {\"stringValue\": \"1.0.0\"}}
        ]
      },
      \"scopeSpans\": [{
        \"spans\": [
          {
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$SPAN1\",
            \"name\": \"parent-operation\",
            \"kind\": 1,
            \"startTimeUnixNano\": \"$NOW\",
            \"endTimeUnixNano\": \"$((NOW + 200000000))\",
            \"attributes\": [
              {\"key\": \"test.type\", \"value\": {\"stringValue\": \"multi-span-single-resource\"}},
              {\"key\": \"span.number\", \"value\": {\"intValue\": \"1\"}}
            ],
            \"status\": {\"code\": 2, \"message\": \"ERROR in parent - should sample 100%\"}
          },
          {
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$SPAN2\",
            \"parentSpanId\": \"$SPAN1\",
            \"name\": \"child-operation-1\",
            \"kind\": 3,
            \"startTimeUnixNano\": \"$((NOW + 10000000))\",
            \"endTimeUnixNano\": \"$((NOW + 50000000))\",
            \"attributes\": [
              {\"key\": \"operation\", \"value\": {\"stringValue\": \"database-query\"}},
              {\"key\": \"span.number\", \"value\": {\"intValue\": \"2\"}}
            ],
            \"status\": {\"code\": 1}
          },
          {
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$SPAN3\",
            \"parentSpanId\": \"$SPAN1\",
            \"name\": \"child-operation-2\",
            \"kind\": 3,
            \"startTimeUnixNano\": \"$((NOW + 60000000))\",
            \"endTimeUnixNano\": \"$((NOW + 120000000))\",
            \"attributes\": [
              {\"key\": \"operation\", \"value\": {\"stringValue\": \"cache-lookup\"}},
              {\"key\": \"span.number\", \"value\": {\"intValue\": \"3\"}}
            ],
            \"status\": {\"code\": 1}
          },
          {
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$SPAN4\",
            \"parentSpanId\": \"$SPAN2\",
            \"name\": \"grandchild-operation\",
            \"kind\": 3,
            \"startTimeUnixNano\": \"$((NOW + 20000000))\",
            \"endTimeUnixNano\": \"$((NOW + 40000000))\",
            \"attributes\": [
              {\"key\": \"operation\", \"value\": {\"stringValue\": \"sub-query\"}},
              {\"key\": \"span.number\", \"value\": {\"intValue\": \"4\"}}
            ],
            \"status\": {\"code\": 1}
          }
        ]
      }]
    }]
  }"

echo ""
echo "✅ Sent multi-span trace from single service!"
echo ""
echo "📊 Trace details:"
echo "   Trace ID: $TRACE_ID"
echo "   Service: MULTI-SPAN-TEST-SERVICE"
echo "   Spans: 4 (all in same resourceSpan)"
echo "   Hierarchy: parent → child1, child2 → grandchild"
echo ""
echo "🔍 Search Axiom for:"
echo "   • service.name = \"MULTI-SPAN-TEST-SERVICE\""
echo "   • You should see all 4 spans together"
