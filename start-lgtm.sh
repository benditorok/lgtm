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
echo "🌐 Access URLs:"
echo "   • Grafana:          http://localhost:3000 (admin/admin123)"
echo "   • Prometheus:       http://localhost:9090"
echo "   • Mimir:            http://localhost:8080"
echo "   • Loki:             http://localhost:3100"
echo "   • Tempo:            http://localhost:3200"
echo "   • OTEL Collector:   http://localhost:13133"
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
