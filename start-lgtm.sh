#!/bin/bash
# LGTM Stack with Mimir Integration - Startup Script

echo "🚀 Starting LGTM Stack with Mimir..."

# Create necessary data directories
echo "📁 Creating data directories..."
mkdir -p data/{grafana,loki,tempo,prometheus,mimir}

# Start the stack
echo "🐳 Starting Docker Compose stack..."
docker compose up -d

echo "⏳ Waiting for services to be healthy..."
sleep 5

# Check service health
echo "🔍 Checking service status..."
docker compose ps

echo ""
echo "✅ LGTM Stack with Mimir is starting up!"
echo ""
echo "🌐 Externally accessible URLs:"
echo "   • Grafana Web UI:    http://localhost:3000 (admin/admin123)"
echo "   • OTLP gRPC:         localhost:4317 (for applications)"
echo "   • OTLP HTTP:         localhost:4318 (for applications)"
echo ""
echo "🔒 Internal services (accessible only within container network):"
echo "   • Prometheus:        http://prometheus:9090"
echo "   • Mimir:             http://mimir:8080"
echo "   • Loki:              http://loki:3100"
echo "   • Tempo:             http://tempo:3200"
echo "   • OTEL Self-Monitor: http://otel-collector:8888"
echo ""
echo "📊 Datasources in Grafana:"
echo "   • Prometheus (local, 15d retention)"
echo "   • Mimir (long-term metrics storage)"
echo "   • Loki (logs)"
echo "   • Tempo (traces)"
echo ""
echo "🔄 Data flow:"
echo "   • Metrics: Apps → OTEL → Prometheus + Mimir"
echo "   • Logs:    Apps → OTEL → Loki"
echo "   • Traces:  Apps → OTEL → Tempo"
