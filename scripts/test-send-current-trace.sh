#!/bin/bash

# Send a test trace with CURRENT timestamp to OTel collector
COLLECTOR_URL="${1:-http://localhost:4318}"

echo "Sending test trace with CURRENT timestamp to $COLLECTOR_URL"

# Get current time in nanoseconds since epoch
NOW_NANOS=$(date +%s%N)
END_NANOS=$((NOW_NANOS + 1000000000))  # +1 second

curl -X POST "$COLLECTOR_URL/v1/traces" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [{
      \"resource\": {
        \"attributes\": [{
          \"key\": \"service.name\",
          \"value\": {\"stringValue\": \"test-service-$(date +%H%M%S)\"}
        }]
      },
      \"scopeSpans\": [{
        \"spans\": [{
          \"traceId\": \"$(uuidgen | tr -d '-' | cut -c1-32)\",
          \"spanId\": \"$(uuidgen | tr -d '-' | cut -c1-16)\",
          \"name\": \"current-timestamp-span\",
          \"kind\": 1,
          \"startTimeUnixNano\": \"$NOW_NANOS\",
          \"endTimeUnixNano\": \"$END_NANOS\",
          \"status\": {
            \"code\": 2,
            \"message\": \"Test error at $(date)\"
          }
        }]
      }]
    }]
  }"

echo ""
echo "✓ Test trace sent with current timestamp"
