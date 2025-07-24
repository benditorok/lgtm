# PowerShell script to manage LGTM stack
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "test", "clean", "debug")]
    [string]$Action,
    
    [string]$Service = ""
)

function Show-Usage {
    Write-Host "Usage: .\manage-stack.ps1 -Action <action> [-Service <service>]"
    Write-Host ""
    Write-Host "Actions:"
    Write-Host "  start     - Start all services"
    Write-Host "  stop      - Stop all services"
    Write-Host "  restart   - Restart all services"
    Write-Host "  status    - Show status of all services"
    Write-Host "  logs      - Show logs (optionally for specific service)"
    Write-Host "  test      - Run test scripts"
    Write-Host "  clean     - Stop and remove all containers and volumes"
    Write-Host "  debug     - Show detailed debug information"
    Write-Host ""
    Write-Host "Services:"
    Write-Host "  prometheus, loki, tempo, grafana, otel-collector"
}

function Start-Stack {
    Write-Host "🚀 Starting LGTM Stack..." -ForegroundColor Green
    docker compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Stack started successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Services available at:"
        Write-Host "  Grafana:        http://localhost:3000 (admin/admin123)"
        Write-Host "  Prometheus:     http://localhost:9090"
        Write-Host "  Loki:           http://localhost:3100"
        Write-Host "  Tempo:          http://localhost:3200"
        Write-Host "  OTEL-Collector: http://localhost:13133 (health)"
        Write-Host ""
        Write-Host "⏱️  Please wait a few minutes for all services to be ready..."
    }
    else {
        Write-Host "❌ Failed to start stack" -ForegroundColor Red
    }
}

function Stop-Stack {
    Write-Host "🛑 Stopping LGTM Stack..." -ForegroundColor Yellow
    docker compose down
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Stack stopped successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Failed to stop stack" -ForegroundColor Red
    }
}

function Restart-Stack {
    Write-Host "🔄 Restarting LGTM Stack..." -ForegroundColor Blue
    docker compose restart
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Stack restarted successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Failed to restart stack" -ForegroundColor Red
    }
}

function Show-Status {
    Write-Host "📊 LGTM Stack Status:" -ForegroundColor Cyan
    docker compose ps
    
    Write-Host ""
    Write-Host "🔍 Health Checks:" -ForegroundColor Cyan
    
    # Check each service
    $services = @(
        @{Name = "Grafana"; URL = "http://localhost:3000/api/health" },
        @{Name = "Prometheus"; URL = "http://localhost:9090/-/healthy" },
        @{Name = "Loki"; URL = "http://localhost:3100/ready" },
        @{Name = "Tempo"; URL = "http://localhost:3200/ready" },
        @{Name = "OTEL-Collector"; URL = "http://localhost:13133" }
    )
    
    foreach ($service in $services) {
        try {
            $response = Invoke-WebRequest -Uri $service.URL -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Host "  ✅ $($service.Name): Healthy" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠️  $($service.Name): Status $($response.StatusCode)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  ❌ $($service.Name): Not responding" -ForegroundColor Red
        }
    }
}

function Show-Logs {
    if ($Service) {
        Write-Host "📋 Showing logs for $Service..." -ForegroundColor Cyan
        docker compose logs -f $Service
    }
    else {
        Write-Host "📋 Showing logs for all services..." -ForegroundColor Cyan
        docker compose logs -f
    }
}

function Invoke-Tests {
    Write-Host "🧪 Running OTEL test script..." -ForegroundColor Magenta
    
    # Check if Python is available
    try {
        python --version | Out-Null
        Write-Host "✅ Python found" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Python not found. Please install Python 3.x" -ForegroundColor Red
        return
    }
    
    # Install required packages
    Write-Host "📦 Installing Python dependencies..."
    pip install requests
    
    # Run test script
    Write-Host "🚀 Sending test telemetry data..."
    python test_otel.py
    
    Write-Host ""
    Write-Host "✅ Test completed! Check Grafana at http://localhost:3000" -ForegroundColor Green
}

function Clear-Stack {
    Write-Host "🧹 Cleaning up LGTM Stack (removing containers and volumes)..." -ForegroundColor Red
    
    $confirmation = Read-Host "This will remove all containers and volumes. Are you sure? (y/N)"
    if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
        docker compose down -v --remove-orphans
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Stack cleaned successfully!" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Failed to clean stack" -ForegroundColor Red
        }
    }
    else {
        Write-Host "❌ Clean operation cancelled" -ForegroundColor Yellow
    }
}

function Show-Debug {
    Write-Host "🔍 LGTM Stack Debug Information:" -ForegroundColor Magenta
    Write-Host ""
    
    # Check Docker version
    Write-Host "🐳 Docker Information:" -ForegroundColor Cyan
    docker --version
    docker compose version
    Write-Host ""
    
    # Show container status with more details
    Write-Host "📦 Container Status:" -ForegroundColor Cyan
    docker compose ps -a
    Write-Host ""
    
    # Check configuration files
    Write-Host "📄 Configuration Files:" -ForegroundColor Cyan
    $configFiles = @(
        "otel-collector\otel-collector-config.yaml",
        "loki\loki-config.yaml", 
        "tempo\tempo-config.yaml",
        "prometheus\prometheus.yml"
    )
    
    foreach ($file in $configFiles) {
        if (Test-Path $file) {
            Write-Host "  ✅ $file exists" -ForegroundColor Green
        }
        else {
            Write-Host "  ❌ $file missing" -ForegroundColor Red
        }
    }
    Write-Host ""
    
    # Show recent error logs for key services
    Write-Host "🚨 Recent Error Logs:" -ForegroundColor Cyan
    $services = @("otel-collector", "loki", "tempo", "prometheus")
    
    foreach ($service in $services) {
        Write-Host "--- $service ---" -ForegroundColor Yellow
        docker compose logs --tail 10 $service 2>$null
        Write-Host ""
    }
    
    # Check ports
    Write-Host "🔌 Port Usage:" -ForegroundColor Cyan
    netstat -an | Select-String ":3000|:3100|:3200|:4317|:4318|:8888|:9090" | ForEach-Object { Write-Host "  $_" }
}

# Main execution
switch ($Action.ToLower()) {
    "start" { Start-Stack }
    "stop" { Stop-Stack }
    "restart" { Restart-Stack }
    "status" { Show-Status }
    "logs" { Show-Logs }
    "test" { Invoke-Tests }
    "clean" { Clear-Stack }
    "debug" { Show-Debug }
    default { Show-Usage }
}
