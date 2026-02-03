#!/bin/bash

# Send a rich distributed trace simulating an e-commerce order processing system
COLLECTOR_URL="${1:-http://localhost:4318}"

echo "🚀 Sending rich distributed trace (order processing flow)..."

# Generate trace ID (shared across all spans)
TRACE_ID=$(uuidgen | tr -d '-' | cut -c1-32)

# Get current time in nanoseconds
NOW_NANOS=$(date +%s%N)

# Calculate span times (in nanoseconds)
# API Gateway: 0ms - 250ms
SPAN1_START=$NOW_NANOS
SPAN1_END=$((NOW_NANOS + 250000000))

# Auth Service: 10ms - 45ms
SPAN2_START=$((NOW_NANOS + 10000000))
SPAN2_END=$((NOW_NANOS + 45000000))

# Order Service: 50ms - 220ms
SPAN3_START=$((NOW_NANOS + 50000000))
SPAN3_END=$((NOW_NANOS + 220000000))

# Database Query (order validation): 60ms - 85ms
SPAN4_START=$((NOW_NANOS + 60000000))
SPAN4_END=$((NOW_NANOS + 85000000))

# Inventory Service: 90ms - 150ms
SPAN5_START=$((NOW_NANOS + 90000000))
SPAN5_END=$((NOW_NANOS + 150000000))

# Redis Cache Check: 95ms - 100ms
SPAN6_START=$((NOW_NANOS + 95000000))
SPAN6_END=$((NOW_NANOS + 100000000))

# Database Query (inventory check): 105ms - 130ms
SPAN7_START=$((NOW_NANOS + 105000000))
SPAN7_END=$((NOW_NANOS + 130000000))

# Payment Service: 160ms - 210ms
SPAN8_START=$((NOW_NANOS + 160000000))
SPAN8_END=$((NOW_NANOS + 210000000))

# External Payment Gateway: 165ms - 205ms (SLOW - 40ms)
SPAN9_START=$((NOW_NANOS + 165000000))
SPAN9_END=$((NOW_NANOS + 205000000))

# Generate span IDs
SPAN1_ID=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN2_ID=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN3_ID=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN4_ID=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN5_ID=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN6_ID=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN7_ID=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN8_ID=$(uuidgen | tr -d '-' | cut -c1-16)
SPAN9_ID=$(uuidgen | tr -d '-' | cut -c1-16)

curl -X POST "$COLLECTOR_URL/v1/traces" \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"api-gateway\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"1.2.3\"}},
            {\"key\": \"deployment.environment\", \"value\": {\"stringValue\": \"production\"}},
            {\"key\": \"host.name\", \"value\": {\"stringValue\": \"api-gateway-prod-01\"}}
          ]
        },
        \"scopeSpans\": [{
          \"scope\": {
            \"name\": \"opentelemetry-go\",
            \"version\": \"1.20.0\"
          },
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$SPAN1_ID\",
            \"name\": \"POST /api/v1/orders\",
            \"kind\": 1,
            \"startTimeUnixNano\": \"$SPAN1_START\",
            \"endTimeUnixNano\": \"$SPAN1_END\",
            \"attributes\": [
              {\"key\": \"http.method\", \"value\": {\"stringValue\": \"POST\"}},
              {\"key\": \"http.route\", \"value\": {\"stringValue\": \"/api/v1/orders\"}},
              {\"key\": \"http.status_code\", \"value\": {\"intValue\": \"200\"}},
              {\"key\": \"http.url\", \"value\": {\"stringValue\": \"https://api.example.com/api/v1/orders\"}},
              {\"key\": \"http.user_agent\", \"value\": {\"stringValue\": \"Mozilla/5.0\"}},
              {\"key\": \"user.id\", \"value\": {\"stringValue\": \"user-12345\"}},
              {\"key\": \"order.id\", \"value\": {\"stringValue\": \"order-98765\"}}
            ],
            \"status\": {\"code\": 1}
          }]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"auth-service\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"2.1.0\"}},
            {\"key\": \"deployment.environment\", \"value\": {\"stringValue\": \"production\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [{
            \"traceId\": \"$TRACE_ID\",
            \"spanId\": \"$SPAN2_ID\",
            \"parentSpanId\": \"$SPAN1_ID\",
            \"name\": \"authenticate_user\",
            \"kind\": 3,
            \"startTimeUnixNano\": \"$SPAN2_START\",
            \"endTimeUnixNano\": \"$SPAN2_END\",
            \"attributes\": [
              {\"key\": \"auth.method\", \"value\": {\"stringValue\": \"jwt\"}},
              {\"key\": \"auth.user_id\", \"value\": {\"stringValue\": \"user-12345\"}},
              {\"key\": \"auth.success\", \"value\": {\"boolValue\": true}}
            ],
            \"status\": {\"code\": 1}
          }]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"order-service\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"3.4.1\"}},
            {\"key\": \"deployment.environment\", \"value\": {\"stringValue\": \"production\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [
            {
              \"traceId\": \"$TRACE_ID\",
              \"spanId\": \"$SPAN3_ID\",
              \"parentSpanId\": \"$SPAN1_ID\",
              \"name\": \"create_order\",
              \"kind\": 3,
              \"startTimeUnixNano\": \"$SPAN3_START\",
              \"endTimeUnixNano\": \"$SPAN3_END\",
              \"attributes\": [
                {\"key\": \"order.id\", \"value\": {\"stringValue\": \"order-98765\"}},
                {\"key\": \"order.total\", \"value\": {\"doubleValue\": 129.99}},
                {\"key\": \"order.items_count\", \"value\": {\"intValue\": \"3\"}},
                {\"key\": \"order.currency\", \"value\": {\"stringValue\": \"USD\"}}
              ],
              \"status\": {\"code\": 1}
            },
            {
              \"traceId\": \"$TRACE_ID\",
              \"spanId\": \"$SPAN4_ID\",
              \"parentSpanId\": \"$SPAN3_ID\",
              \"name\": \"SELECT orders\",
              \"kind\": 3,
              \"startTimeUnixNano\": \"$SPAN4_START\",
              \"endTimeUnixNano\": \"$SPAN4_END\",
              \"attributes\": [
                {\"key\": \"db.system\", \"value\": {\"stringValue\": \"postgresql\"}},
                {\"key\": \"db.name\", \"value\": {\"stringValue\": \"orders_db\"}},
                {\"key\": \"db.statement\", \"value\": {\"stringValue\": \"SELECT * FROM orders WHERE user_id = $1\"}},
                {\"key\": \"db.operation\", \"value\": {\"stringValue\": \"SELECT\"}},
                {\"key\": \"db.rows_affected\", \"value\": {\"intValue\": \"5\"}}
              ],
              \"status\": {\"code\": 1}
            }
          ]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"inventory-service\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"1.8.2\"}},
            {\"key\": \"deployment.environment\", \"value\": {\"stringValue\": \"production\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [
            {
              \"traceId\": \"$TRACE_ID\",
              \"spanId\": \"$SPAN5_ID\",
              \"parentSpanId\": \"$SPAN3_ID\",
              \"name\": \"check_inventory\",
              \"kind\": 3,
              \"startTimeUnixNano\": \"$SPAN5_START\",
              \"endTimeUnixNano\": \"$SPAN5_END\",
              \"attributes\": [
                {\"key\": \"inventory.product_ids\", \"value\": {\"stringValue\": \"[prod-111, prod-222, prod-333]\"}},
                {\"key\": \"inventory.available\", \"value\": {\"boolValue\": true}},
                {\"key\": \"inventory.warehouse\", \"value\": {\"stringValue\": \"warehouse-east\"}}
              ],
              \"status\": {\"code\": 1}
            },
            {
              \"traceId\": \"$TRACE_ID\",
              \"spanId\": \"$SPAN6_ID\",
              \"parentSpanId\": \"$SPAN5_ID\",
              \"name\": \"redis.GET\",
              \"kind\": 3,
              \"startTimeUnixNano\": \"$SPAN6_START\",
              \"endTimeUnixNano\": \"$SPAN6_END\",
              \"attributes\": [
                {\"key\": \"db.system\", \"value\": {\"stringValue\": \"redis\"}},
                {\"key\": \"db.operation\", \"value\": {\"stringValue\": \"GET\"}},
                {\"key\": \"db.redis.key\", \"value\": {\"stringValue\": \"inventory:prod-111\"}},
                {\"key\": \"cache.hit\", \"value\": {\"boolValue\": false}}
              ],
              \"status\": {\"code\": 1}
            },
            {
              \"traceId\": \"$TRACE_ID\",
              \"spanId\": \"$SPAN7_ID\",
              \"parentSpanId\": \"$SPAN5_ID\",
              \"name\": \"SELECT inventory\",
              \"kind\": 3,
              \"startTimeUnixNano\": \"$SPAN7_START\",
              \"endTimeUnixNano\": \"$SPAN7_END\",
              \"attributes\": [
                {\"key\": \"db.system\", \"value\": {\"stringValue\": \"postgresql\"}},
                {\"key\": \"db.name\", \"value\": {\"stringValue\": \"inventory_db\"}},
                {\"key\": \"db.statement\", \"value\": {\"stringValue\": \"SELECT quantity FROM inventory WHERE product_id = ANY($1)\"}},
                {\"key\": \"db.operation\", \"value\": {\"stringValue\": \"SELECT\"}}
              ],
              \"status\": {\"code\": 1}
            }
          ]
        }]
      },
      {
        \"resource\": {
          \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"payment-service\"}},
            {\"key\": \"service.version\", \"value\": {\"stringValue\": \"2.3.0\"}},
            {\"key\": \"deployment.environment\", \"value\": {\"stringValue\": \"production\"}}
          ]
        },
        \"scopeSpans\": [{
          \"spans\": [
            {
              \"traceId\": \"$TRACE_ID\",
              \"spanId\": \"$SPAN8_ID\",
              \"parentSpanId\": \"$SPAN3_ID\",
              \"name\": \"process_payment\",
              \"kind\": 3,
              \"startTimeUnixNano\": \"$SPAN8_START\",
              \"endTimeUnixNano\": \"$SPAN8_END\",
              \"attributes\": [
                {\"key\": \"payment.method\", \"value\": {\"stringValue\": \"credit_card\"}},
                {\"key\": \"payment.amount\", \"value\": {\"doubleValue\": 129.99}},
                {\"key\": \"payment.currency\", \"value\": {\"stringValue\": \"USD\"}},
                {\"key\": \"payment.provider\", \"value\": {\"stringValue\": \"stripe\"}}
              ],
              \"status\": {\"code\": 1}
            },
            {
              \"traceId\": \"$TRACE_ID\",
              \"spanId\": \"$SPAN9_ID\",
              \"parentSpanId\": \"$SPAN8_ID\",
              \"name\": \"POST https://api.stripe.com/v1/charges\",
              \"kind\": 2,
              \"startTimeUnixNano\": \"$SPAN9_START\",
              \"endTimeUnixNano\": \"$SPAN9_END\",
              \"attributes\": [
                {\"key\": \"http.method\", \"value\": {\"stringValue\": \"POST\"}},
                {\"key\": \"http.url\", \"value\": {\"stringValue\": \"https://api.stripe.com/v1/charges\"}},
                {\"key\": \"http.status_code\", \"value\": {\"intValue\": \"200\"}},
                {\"key\": \"peer.service\", \"value\": {\"stringValue\": \"stripe-api\"}}
              ],
              \"status\": {\"code\": 1}
            }
          ]
        }]
      }
    ]
  }"

echo ""
echo "✅ Rich trace sent successfully!"
echo ""
echo "📊 Trace details:"
echo "   Trace ID: $TRACE_ID"
echo "   Services: 5 (api-gateway, auth-service, order-service, inventory-service, payment-service)"
echo "   Spans: 9"
echo "   Duration: ~250ms"
echo ""
echo "🔍 What to look for in Axiom:"
echo "   • Service map showing all 5 services"
echo "   • Parent-child span relationships"
echo "   • Database queries (PostgreSQL)"
echo "   • Cache operations (Redis)"
echo "   • External HTTP call (Stripe API)"
echo "   • Rich attributes (order details, payment info, etc.)"
