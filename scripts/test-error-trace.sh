#!/bin/bash

# Send a trace with errors to test error sampling (should be kept 100%)
COLLECTOR_URL="${1:-http://localhost:4318}"

echo "⚠️  Sending trace with errors (testing error sampling)..."

TRACE_ID=$(uuidgen | tr -d '-' | cut -c1-32)
NOW_NANOS=$(date +%s%N)

# API call: 0ms - 8000ms (8 seconds - SLOW!)
SPAN1_START=$NOW_NANOS
SPAN1_END=$((NOW_NANOS + 8000000000))

# Database connection: 10ms - 7500ms (times out)
SPAN2_START=$((NOW_NANOS + 10000000))
SPAN2_END=$((NOW_NANOS + 7500000000))

# Retry attempt: 7600ms - 7950ms (also fails)
SPAN3_START=$((NOW_NANOS + 7600000000))
SPAN3_END=$((NOW_NANOS + 7950000000))

SPAN1_ID=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN2_ID=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN3_ID=$(uuidgen | tr -d '-' | cut -c1-16)

curl -X POST "$COLLECTOR_URL/v1/traces" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"checkout-service\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"1.0.5\"}},
            {\"key\": \"deployment.environment\", \"value\": {\"stringValue\": \"production\"}},
            {\"key\": \"host.name\", \"value\": {\"stringValue\": \"checkout-prod-03\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [
            {
              \"traceId\": \"$TRACE_ID\",
              \"spanId\": \"$SPAN1_ID\",
              \"name\": \"POST /api/checkout\",
              \"kind\": 1,
              \"startTimeUnixNano\": \"$SPAN1_START\",
              \"endTimeUnixNano\": \"$SPAN1_END\",
              \"attributes\": [
                {\"key\": \"http.method\", \"value\": {\"stringValue\": \"POST\"}},
                {\"key\": \"http.route\", \"value\": {\"stringValue\": \"/api/checkout\"}},
                {\"key\": \"http.status_code\", \"value\": {\"intValue\": \"500\"}},
                {\"key\": \"error.type\", \"value\": {\"stringValue\": \"DatabaseConnectionError\"}},
                {\"key\": \"user.id\", \"value\": {\"stringValue\": \"user-99999\"}}
              ],
              \"status\": {
                \"code\": 2,
                \"message\": \"Database connection timeout after 3 retry attempts\"
              },
              \"events\": [
                {
                  \"timeUnixNano\": \"$((NOW_NANOS + 7500000000))\",
                  \"name\": \"exception\",
                  \"attributes\": [
                    {\"key\": \"exception.type\", \"value\": {\"stringValue\": \"TimeoutError\"}},
                    {\"key\": \"exception.message\", \"value\": {\"stringValue\": \"Connection to database timed out\"}},
                    {\"key\": \"exception.stacktrace\", \"value\": {\"stringValue\": \"at Database.connect() [database.js:45]\\\\nat CheckoutService.processCheckout() [checkout.js:23]\"}}
                  ]
                }
              ]
            },
            {
              \"traceId\": \"$TRACE_ID\",
              \"spanId\": \"$SPAN2_ID\",
              \"parentSpanId\": \"$SPAN1_ID\",
              \"name\": \"db.connect\",
              \"kind\": 3,
              \"startTimeUnixNano\": \"$SPAN2_START\",
              \"endTimeUnixNano\": \"$SPAN2_END\",
              \"attributes\": [
                {\"key\": \"db.system\", \"value\": {\"stringValue\": \"postgresql\"}},
                {\"key\": \"db.connection_string\", \"value\": {\"stringValue\": \"postgresql://db-primary:5432/checkout\"}},
                {\"key\": \"db.pool.size\", \"value\": {\"intValue\": \"20\"}},
                {\"key\": \"db.pool.available\", \"value\": {\"intValue\": \"0\"}},
                {\"key\": \"error.message\", \"value\": {\"stringValue\": \"All connections in pool are busy\"}}
              ],
              \"status\": {
                \"code\": 2,
                \"message\": \"Connection pool exhausted - timeout waiting for available connection\"
              }
            },
            {
              \"traceId\": \"$TRACE_ID\",
              \"spanId\": \"$SPAN3_ID\",
              \"parentSpanId\": \"$SPAN1_ID\",
              \"name\": \"db.connect.retry\",
              \"kind\": 3,
              \"startTimeUnixNano\": \"$SPAN3_START\",
              \"endTimeUnixNano\": \"$SPAN3_END\",
              \"attributes\": [
                {\"key\": \"db.system\", \"value\": {\"stringValue\": \"postgresql\"}},
                {\"key\": \"retry.attempt\", \"value\": {\"intValue\": \"3\"}},
                {\"key\": \"retry.max_attempts\", \"value\": {\"intValue\": \"3\"}}
              ],
              \"status\": {
                \"code\": 2,
                \"message\": \"Retry failed: max attempts reached\"
              }
            }
          ]
        }]
      }
    ]
  }"

echo ""
echo "✅ Error trace sent!"
echo ""
echo "📊 Trace details:"
echo "   Trace ID: $TRACE_ID"
echo "   Status: ERROR (will be kept 100%)"
echo "   Duration: 8 seconds (SLOW - will be kept 100%)"
echo "   Error: Database connection timeout"
echo ""
echo "🎯 This trace tests BOTH sampling policies:"
echo "   ✓ Error policy: Has ERROR status → kept 100%"
echo "   ✓ Latency policy: >5 seconds → kept 100%"
echo "   ✓ Contains exception events with stack traces"
