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
        echo "   • Grafana Web UI:    http://localhost:${GRAFANA_PORT:-3000} (${GRAFANA_ADMIN_USER:-admin}/${GRAFANA_ADMIN_PASSWORD:-admin123})"
        echo "   • OTLP gRPC:         localhost:${OTEL_GRPC_PORT:-4317} (for applications)"
        echo "   • OTLP HTTP:         localhost:${OTEL_HTTP_PORT:-4318} (for applications)"
        echo "   • OTEL Health:       http://localhost:${OTEL_HEALTH_PORT:-13133} (health checks)"
        echo ""
        echo -e "${CYAN}🔒 Internal services (accessible only within container network):${NC}"
        echo "   • Prometheus:        http://prometheus:${PROMETHEUS_INTERNAL_PORT:-9090}"
        echo "   • Mimir:             http://mimir:${MIMIR_INTERNAL_PORT:-8080}"
        echo "   • Loki:              http://loki:${LOKI_INTERNAL_PORT:-3100}"
        echo "   • Tempo:             http://tempo:${TEMPO_INTERNAL_PORT:-3200}"
        echo "   • OTEL Self-Monitor: http://otel-collector:${OTEL_METRICS_PORT:-8888}"
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
        "Grafana:http://localhost:${GRAFANA_PORT:-3000}/api/health"
        "OTEL-Collector:http://localhost:${OTEL_HEALTH_PORT:-13133}"
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
    internal_services=("prometheus:${PROMETHEUS_INTERNAL_PORT:-9090}" "mimir:${MIMIR_INTERNAL_PORT:-8080}" "loki:${LOKI_INTERNAL_PORT:-3100}" "tempo:${TEMPO_INTERNAL_PORT:-3200}")
    
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
    echo -e "${MAGENTA}🧪 Running C# OTEL test script...${NC}"
    
    # Check if .NET is available
    if ! command -v dotnet &> /dev/null; then
        echo -e "${RED}❌ .NET not found. Please install .NET SDK${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ .NET found${NC}"
    
    # Check if test.cs exists
    if [ -f "test.cs" ]; then
        echo -e "${GREEN}✅ Using C# test script: test.cs${NC}"
    else
        echo -e "${RED}❌ test.cs not found. Please ensure test.cs exists${NC}"
        return 1
    fi
    
    # Run C# test script
    echo -e "${BLUE}🚀 Sending test telemetry data...${NC}"
    ./test.cs
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
    netstat -tuln | grep -E ":${GRAFANA_PORT:-3000}|:${OTEL_GRPC_PORT:-4317}|:${OTEL_HTTP_PORT:-4318}|:${OTEL_HEALTH_PORT:-13133}" | while read line; do
        echo "  $line"
    done
    echo "  Note: Internal ports (${LOKI_INTERNAL_PORT:-3100},${TEMPO_INTERNAL_PORT:-3200},${MIMIR_INTERNAL_PORT:-8080},${OTEL_METRICS_PORT:-8888},${PROMETHEUS_INTERNAL_PORT:-9090}) are not exposed externally"
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
