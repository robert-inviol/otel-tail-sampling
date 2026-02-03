#!/bin/bash

# Demonstrate trace context propagation across service boundaries
# Simulates: API Gateway → Auth → Order Service → Database → Payment → Stripe

COLLECTOR_URL="${1:-http://localhost:4318}"

echo "🔗 Simulating trace propagation across service chain..."
echo ""
echo "   Flow: API Gateway → Auth → Order → DB → Payment → Stripe"
echo ""

# Shared trace ID (this is what gets propagated!)
TRACE_ID=$(uuidgen | tr -d '-' | cut -c1-32)

# Generate span IDs
GATEWAY_SPAN=$(uuidgen | tr -d '-' | cut -c1-16)
AUTH_SPAN=$(uuidgen | tr -d '-' | cut -c1-16)
ORDER_SPAN=$(uuidgen | tr -d '-' | cut -c1-16)
DB_SPAN=$(uuidgen | tr -d '-' | cut -c1-16)
PAYMENT_SPAN=$(uuidgen | tr -d '-' | cut -c1-16)
STRIPE_SPAN=$(uuidgen | tr -d '-' | cut -c1-16)

# Time calculation
NOW=$(date +%s%N)

# API Gateway: 0-200ms
T1_START=$NOW
T1_END=$((NOW + 200000000))

# Auth Service: 10-50ms (called by Gateway)
T2_START=$((NOW + 10000000))
T2_END=$((NOW + 50000000))

# Order Service: 60-180ms (called by Gateway after auth)
T3_START=$((NOW + 60000000))
T3_END=$((NOW + 180000000))

# Database: 70-100ms (called by Order Service)
T4_START=$((NOW + 70000000))
T4_END=$((NOW + 100000000))

# Payment Service: 110-170ms (called by Order Service)
T5_START=$((NOW + 110000000))
T5_END=$((NOW + 170000000))

# Stripe API: 120-160ms (called by Payment Service)
T6_START=$((NOW + 120000000))
T6_END=$((NOW + 160000000))

echo "📊 Sending trace with propagation chain:"
echo ""
echo "   Trace ID: $TRACE_ID"
echo ""
echo "   1. API Gateway     (span: $GATEWAY_SPAN)"
echo "      └→ traceparent: 00-$TRACE_ID-$GATEWAY_SPAN-01"
echo ""
echo "   2. Auth Service    (span: $AUTH_SPAN, parent: $GATEWAY_SPAN)"
echo "      └→ Extracted from header, added as child"
echo ""
echo "   3. Order Service   (span: $ORDER_SPAN, parent: $GATEWAY_SPAN)"
echo "      └→ Extracted from header, added as child"
echo ""
echo "   4. Database        (span: $DB_SPAN, parent: $ORDER_SPAN)"
echo "      └→ Child of Order Service"
echo ""
echo "   5. Payment Service (span: $PAYMENT_SPAN, parent: $ORDER_SPAN)"
echo "      └→ Child of Order Service"
echo ""
echo "   6. Stripe API      (span: $STRIPE_SPAN, parent: $PAYMENT_SPAN)"
echo "      └→ Child of Payment Service"
echo ""

curl -s -X POST "$COLLECTOR_URL/v1/traces" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"api-gateway\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"1.0.0\"}},
            {\"key\": \"http.host\", \"value\": {\"stringValue\": \"api.example.com\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$GATEWAY_SPAN\",
            \"name\": \"POST /api/checkout\",
            \"kind\": 1,
            \"startTimeUnixNano\": \"$T1_START\",
            \"endTimeUnixNano\": \"$T1_END\",
            \"attributes\": [
              {\"key\": \"http.method\", \"value\": {\"stringValue\": \"POST\"}},
              {\"key\": \"http.route\", \"value\": {\"stringValue\": \"/api/checkout\"}},
              {\"key\": \"http.status_code\", \"value\": {\"intValue\": \"200\"}},
              {\"key\": \"propagation.method\", \"value\": {\"stringValue\": \"W3C Trace Context\"}},
              {\"key\": \"traceparent.sent\", \"value\": {\"stringValue\": \"00-$TRACE_ID-$GATEWAY_SPAN-01\"}}
            ],
            \"status\": {\"code\": 1}
          }]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"auth-service\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"2.1.0\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$AUTH_SPAN\",
            \"parentSpanId\": \"$GATEWAY_SPAN\",
            \"name\": \"authenticate_user\",
            \"kind\": 3,
            \"startTimeUnixNano\": \"$T2_START\",
            \"endTimeUnixNano\": \"$T2_END\",
            \"attributes\": [
              {\"key\": \"auth.method\", \"value\": {\"stringValue\": \"oauth2\"}},
              {\"key\": \"traceparent.received\", \"value\": {\"stringValue\": \"00-$TRACE_ID-$GATEWAY_SPAN-01\"}},
              {\"key\": \"context.extracted\", \"value\": {\"boolValue\": true}}
            ],
            \"status\": {\"code\": 1}
          }]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"order-service\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"3.2.0\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$ORDER_SPAN\",
            \"parentSpanId\": \"$GATEWAY_SPAN\",
            \"name\": \"create_order\",
            \"kind\": 3,
            \"startTimeUnixNano\": \"$T3_START\",
            \"endTimeUnixNano\": \"$T3_END\",
            \"attributes\": [
              {\"key\": \"order.id\", \"value\": {\"stringValue\": \"order-777\"}},
              {\"key\": \"traceparent.received\", \"value\": {\"stringValue\": \"00-$TRACE_ID-$GATEWAY_SPAN-01\"}},
              {\"key\": \"context.extracted\", \"value\": {\"boolValue\": true}},
              {\"key\": \"traceparent.sent_to_db\", \"value\": {\"stringValue\": \"00-$TRACE_ID-$ORDER_SPAN-01\"}}
            ],
            \"status\": {\"code\": 1}
          }]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"postgres-db\"}},
            {\"key\": \"db.system\", \"value\": {\"stringValue\": \"postgresql\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$DB_SPAN\",
            \"parentSpanId\": \"$ORDER_SPAN\",
            \"name\": \"INSERT INTO orders\",
            \"kind\": 3,
            \"startTimeUnixNano\": \"$T4_START\",
            \"endTimeUnixNano\": \"$T4_END\",
            \"attributes\": [
              {\"key\": \"db.system\", \"value\": {\"stringValue\": \"postgresql\"}},
              {\"key\": \"db.operation\", \"value\": {\"stringValue\": \"INSERT\"}},
              {\"key\": \"db.statement\", \"value\": {\"stringValue\": \"INSERT INTO orders (id, user_id, total) VALUES ($1, $2, $3)\"}},
              {\"key\": \"traceparent.received\", \"value\": {\"stringValue\": \"00-$TRACE_ID-$ORDER_SPAN-01\"}}
            ],
            \"status\": {\"code\": 1}
          }]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"payment-service\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"4.0.0\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$PAYMENT_SPAN\",
            \"parentSpanId\": \"$ORDER_SPAN\",
            \"name\": \"process_payment\",
            \"kind\": 3,
            \"startTimeUnixNano\": \"$T5_START\",
            \"endTimeUnixNano\": \"$T5_END\",
            \"attributes\": [
              {\"key\": \"payment.amount\", \"value\": {\"doubleValue\": 99.99}},
              {\"key\": \"payment.currency\", \"value\": {\"stringValue\": \"USD\"}},
              {\"key\": \"traceparent.received\", \"value\": {\"stringValue\": \"00-$TRACE_ID-$ORDER_SPAN-01\"}},
              {\"key\": \"traceparent.sent_to_stripe\", \"value\": {\"stringValue\": \"00-$TRACE_ID-$PAYMENT_SPAN-01\"}}
            ],
            \"status\": {\"code\": 1}
          }]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"stripe-api\"}},
            {\"key\": \"peer.service\", \"value\": {\"stringValue\": \"stripe.com\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$STRIPE_SPAN\",
            \"parentSpanId\": \"$PAYMENT_SPAN\",
            \"name\": \"POST /v1/charges\",
            \"kind\": 2,
            \"startTimeUnixNano\": \"$T6_START\",
            \"endTimeUnixNano\": \"$T6_END\",
            \"attributes\": [
              {\"key\": \"http.method\", \"value\": {\"stringValue\": \"POST\"}},
              {\"key\": \"http.url\", \"value\": {\"stringValue\": \"https://api.stripe.com/v1/charges\"}},
              {\"key\": \"http.status_code\", \"value\": {\"intValue\": \"200\"}},
              {\"key\": \"traceparent.received\", \"value\": {\"stringValue\": \"00-$TRACE_ID-$PAYMENT_SPAN-01\"}}
            ],
            \"status\": {\"code\": 1}
          }]
        }]
      }
    ]
  }" > /dev/null

echo "✅ Trace sent with full propagation chain!"
echo ""
echo "🔍 In Axiom, look for trace: $TRACE_ID"
echo ""
echo "You should see:"
echo "  • All 6 spans linked together in one trace"
echo "  • Service map: Gateway → Auth, Order → DB, Payment → Stripe"
echo "  • Waterfall showing request flow through services"
echo "  • Each span has traceparent.received showing propagation"
echo ""
echo "📖 See docs/trace-propagation.md for code examples"
