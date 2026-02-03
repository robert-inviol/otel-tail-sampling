#!/bin/bash

# Send multiple successful traces to demonstrate probabilistic sampling (10%)
COLLECTOR_URL="${1:-http://localhost:4318}"
COUNT="${2:-20}"

echo "✨ Sending $COUNT successful traces (testing 10% probabilistic sampling)..."
echo ""

for i in $(seq 1 $COUNT); do
  TRACE_ID=$(uuidgen | tr -d '-' | cut -c1-32)
  SPAN_ID=$(uuidgen | tr -d '-' | cut -c1-16)
  NOW_NANOS=$(date +%s%N)
  END_NANOS=$((NOW_NANOS + $((50000000 + RANDOM % 200000000))))  # 50-250ms

  curl -s -X POST "$COLLECTOR_URL/v1/traces" \
    -H "Content-Type: application/json" \
    -d "{
      \"resourceSpans\": [{
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"user-service\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"2.0.1\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$SPAN_ID\",
            \"name\": \"GET /api/users/$i\",
            \"kind\": 1,
            \"startTimeUnixNano\": \"$NOW_NANOS\",
            \"endTimeUnixNano\": \"$END_NANOS\",
            \"attributes\": [
              {\"key\": \"http.method\", \"value\": {\"stringValue\": \"GET\"}},
              {\"key\": \"http.route\", \"value\": {\"stringValue\": \"/api/users/:id\"}},
              {\"key\": \"http.status_code\", \"value\": {\"intValue\": \"200\"}},
              {\"key\": \"user.id\", \"value\": {\"stringValue\": \"user-$i\"}}
            ],
            \"status\": {\"code\": 1}
          }]
        }]
      }]
    }" > /dev/null

  echo "  [$i/$COUNT] Trace sent: $TRACE_ID"
  sleep 0.1
done

echo ""
echo "✅ All $COUNT successful traces sent!"
echo ""
echo "📊 Expected sampling results (after 10s decision wait):"
echo "   • Sent: $COUNT traces"
echo "   • Expected to be kept: ~$((COUNT / 10)) traces (10% sampling)"
echo "   • Expected to be dropped: ~$((COUNT * 9 / 10)) traces"
echo ""
echo "⏱️  Wait 10 seconds for tail sampling decisions..."
