#!/bin/bash
# LGTM Stack with Mimir Management Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

function show_usage() {
    echo "Usage: ./manage-stack.sh <action> [service]"
    echo ""
    echo "Actions:"
    echo "  start     - Start all services"
    echo "  stop      - Stop all services"  
    echo "  restart   - Restart all services"
    echo "  status    - Show status of all services"
    echo "  logs      - Show logs (optionally for specific service)"
    echo "  test      - Run test scripts"
    echo "  clean     - Stop and remove all containers and volumes"
    echo "  debug     - Show detailed debug information"
    echo ""
    echo "Services:"
    echo "  prometheus, loki, tempo, mimir, grafana, otel-collector"
}

function start_stack() {
    echo -e "${GREEN}🚀 Starting LGTM Stack with Mimir...${NC}"
    
    # Create necessary data directories
    echo -e "${YELLOW}📁 Creating data directories...${NC}"
    mkdir -p data/{grafana,loki,tempo,prometheus,mimir}
    
    docker compose up -d
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Stack started successfully!${NC}"
        echo ""
        echo -e "${CYAN}🌐 Externally accessible URLs:${NC}"
        echo "   • Grafana Web UI:    http://localhost:3000 (admin/admin123)"
        echo "   • OTLP gRPC:         localhost:4317 (for applications)"
        echo "   • OTLP HTTP:         localhost:4318 (for applications)"
        echo ""
        echo -e "${CYAN}🔒 Internal services (accessible only within container network):${NC}"
        echo "   • Prometheus:        http://prometheus:9090"
        echo "   • Mimir:             http://mimir:8080"
        echo "   • Loki:              http://loki:3100"
        echo "   • Tempo:             http://tempo:3200"
        echo "   • OTEL Self-Monitor: http://otel-collector:8888"
        echo ""
        echo -e "${YELLOW}⏱️  Please wait a few minutes for all services to be ready...${NC}"
    else
        echo -e "${RED}❌ Failed to start stack${NC}"
        exit 1
    fi
}

function stop_stack() {
    echo -e "${YELLOW}🛑 Stopping LGTM Stack...${NC}"
    docker compose down
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Stack stopped successfully!${NC}"
    else
        echo -e "${RED}❌ Failed to stop stack${NC}"
        exit 1
    fi
}

function restart_stack() {
    echo -e "${BLUE}🔄 Restarting LGTM Stack...${NC}"
    docker compose restart
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Stack restarted successfully!${NC}"
    else
        echo -e "${RED}❌ Failed to restart stack${NC}"
        exit 1
    fi
}

function show_status() {
    echo -e "${CYAN}📊 LGTM Stack Status:${NC}"
    docker compose ps
    
    echo ""
    echo -e "${CYAN}🔍 Health Checks:${NC}"
    
    # Check externally accessible services
    services=(
        "Grafana:http://localhost:3000/api/health"
        "OTEL-Collector:http://localhost:13133"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r name url <<< "$service_info"
        if curl -s --max-time 5 "$url" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✅ $name: Healthy${NC}"
        else
            echo -e "  ${RED}❌ $name: Not responding${NC}"
        fi
    done
    
    echo ""
    echo -e "${CYAN}🔒 Internal Services Status:${NC}"
    
    # Check internal services by container status
    internal_services=("prometheus:9090" "mimir:8080" "loki:3100" "tempo:3200")
    
    for service_info in "${internal_services[@]}"; do
        IFS=':' read -r container port <<< "$service_info"
        status=$(docker compose ps --format "{{.State}}" "$container" 2>/dev/null)
        if [ "$status" = "running" ]; then
            echo -e "  ${GREEN}✅ ${container^}: Running (internal port $port)${NC}"
        else
            echo -e "  ${RED}❌ ${container^}: $status${NC}"
        fi
    done
}

function show_logs() {
    if [ -n "$2" ]; then
        echo -e "${CYAN}📋 Showing logs for $2...${NC}"
        docker compose logs -f "$2"
    else
        echo -e "${CYAN}📋 Showing logs for all services...${NC}"
        docker compose logs -f
    fi
}

function run_tests() {
    echo -e "${MAGENTA}🧪 Running OTEL test script...${NC}"
    
    # Check if Python is available
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}❌ Python 3 not found. Please install Python 3.x${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Python 3 found${NC}"
    
    # Install required packages
    echo -e "${YELLOW}📦 Installing Python dependencies...${NC}"
    pip3 install requests
    
    # Create a simple test script
    cat > test_otel.py << 'EOF'
#!/usr/bin/env python3
import requests
import json
import time

def test_otel_endpoints():
    print("🧪 Testing OpenTelemetry Collector endpoints...")
    
    # Test health endpoint
    try:
        response = requests.get('http://localhost:13133', timeout=5)
        if response.status_code == 200:
            print("✅ OTEL Collector health endpoint: OK")
        else:
            print(f"⚠️  OTEL Collector health endpoint: Status {response.status_code}")
    except Exception as e:
        print(f"❌ OTEL Collector health endpoint: {e}")
    
    # Test OTLP HTTP endpoint (simple test)
    try:
        test_data = {
            "resourceMetrics": [{
                "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "test-service"}}]},
                "instrumentationLibraryMetrics": [{
                    "instrumentationLibrary": {"name": "test"},
                    "metrics": [{
                        "name": "test_metric",
                        "gauge": {"dataPoints": [{"timeUnixNano": str(int(time.time() * 1_000_000_000)), "asDouble": 42.0}]}
                    }]
                }]
            }]
        }
        
        headers = {'Content-Type': 'application/json'}
        response = requests.post('http://localhost:4318/v1/metrics', 
                               json=test_data, headers=headers, timeout=5)
        
        if response.status_code in [200, 202]:
            print("✅ OTLP HTTP endpoint: Accepting metrics")
        else:
            print(f"⚠️  OTLP HTTP endpoint: Status {response.status_code}")
    except Exception as e:
        print(f"❌ OTLP HTTP endpoint: {e}")

if __name__ == "__main__":
    test_otel_endpoints()
    print("✅ Test completed! Check Grafana at http://localhost:3000")
EOF
    
    # Run test script
    echo -e "${BLUE}🚀 Sending test telemetry data...${NC}"
    python3 test_otel.py
    
    # Clean up
    rm -f test_otel.py
}

function clean_stack() {
    echo -e "${RED}🧹 Cleaning up LGTM Stack (removing containers and volumes)...${NC}"
    
    read -p "This will remove all containers and volumes. Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose down -v --remove-orphans
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Stack cleaned successfully!${NC}"
        else
            echo -e "${RED}❌ Failed to clean stack${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}❌ Clean operation cancelled${NC}"
    fi
}

function show_debug() {
    echo -e "${MAGENTA}🔍 LGTM Stack Debug Information:${NC}"
    echo ""
    
    # Check Docker version
    echo -e "${CYAN}🐳 Docker Information:${NC}"
    docker --version
    docker compose version
    echo ""
    
    # Show container status with more details
    echo -e "${CYAN}📦 Container Status:${NC}"
    docker compose ps -a
    echo ""
    
    # Check configuration files
    echo -e "${CYAN}📄 Configuration Files:${NC}"
    config_files=(
        "otel-collector/otel-collector-config.yaml"
        "loki/loki-config.yaml" 
        "tempo/tempo-config.yaml"
        "prometheus/prometheus.yml"
        "mimir/mimir-config.yaml"
    )
    
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            echo -e "  ${GREEN}✅ $file exists${NC}"
        else
            echo -e "  ${RED}❌ $file missing${NC}"
        fi
    done
    echo ""
    
    # Show recent error logs for key services
    echo -e "${CYAN}🚨 Recent Error Logs:${NC}"
    services=("otel-collector" "loki" "tempo" "prometheus" "mimir")
    
    for service in "${services[@]}"; do
        echo -e "${YELLOW}--- $service ---${NC}"
        docker compose logs --tail 10 "$service" 2>/dev/null || echo "Service not found"
        echo ""
    done
    
    # Check ports
    echo -e "${CYAN}🔌 Port Usage:${NC}"
    netstat -tuln | grep -E ':3000|:4317|:4318' | while read line; do
        echo "  $line"
    done
    echo "  Note: Internal ports (3100,3200,8080,8888,9090) are not exposed externally"
}

# Main execution
case "${1:-}" in
    "start")
        start_stack
        ;;
    "stop")
        stop_stack
        ;;
    "restart")
        restart_stack
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs "$@"
        ;;
    "test")
        run_tests
        ;;
    "clean")
        clean_stack
        ;;
    "debug")
        show_debug
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
