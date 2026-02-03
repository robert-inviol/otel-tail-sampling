# Use the official OpenTelemetry Collector Contrib image
FROM otel/opentelemetry-collector-contrib:0.96.0

# Copy the configuration file
COPY otel-collector-config.yaml /etc/otelcol-contrib/config.yaml

# Expose ports
# OTLP gRPC receiver
EXPOSE 4317
# OTLP HTTP receiver
EXPOSE 4318
# Prometheus metrics
EXPOSE 8888
# Health check
EXPOSE 13133

# Set the config file location
ENV OTEL_CONFIG_FILE=/etc/otelcol-contrib/config.yaml

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:13133/ || exit 1

# Run the collector
CMD ["--config", "/etc/otelcol-contrib/config.yaml"]
