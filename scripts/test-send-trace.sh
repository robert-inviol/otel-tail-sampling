#!/bin/bash
# Simple script to send a test trace to the collector

COLLECTOR_ENDPOINT="${COLLECTOR_ENDPOINT:-http://localhost:4318}"

echo "Sending test trace to $COLLECTOR_ENDPOINT"

# Send a test span via OTLP HTTP
curl -X POST "$COLLECTOR_ENDPOINT/v1/traces" \
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
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "test-span",
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

echo -e "\n✓ Test trace sent"
