# PowerShell script to manage LGTM stack with Mimir
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
    Write-Host "  prometheus, loki, tempo, mimir, grafana, otel-collector"
}

function Start-Stack {
    Write-Host "🚀 Starting LGTM Stack with Mimir..." -ForegroundColor Green
    
    # Create necessary data directories
    Write-Host "📁 Creating data directories..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path "data\grafana" | Out-Null
    New-Item -ItemType Directory -Force -Path "data\loki" | Out-Null
    New-Item -ItemType Directory -Force -Path "data\tempo" | Out-Null
    New-Item -ItemType Directory -Force -Path "data\prometheus" | Out-Null
    New-Item -ItemType Directory -Force -Path "data\mimir" | Out-Null
    
    docker compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Stack started successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🌐 Externally accessible URLs:"
        Write-Host "   • Grafana Web UI:    http://localhost:$($env:GRAFANA_PORT ?? '3000') ($($env:GRAFANA_ADMIN_USER ?? 'admin')/$($env:GRAFANA_ADMIN_PASSWORD ?? 'admin123'))"
        Write-Host "   • OTLP gRPC:         localhost:$($env:OTEL_GRPC_PORT ?? '4317') (for applications)"
        Write-Host "   • OTLP HTTP:         localhost:$($env:OTEL_HTTP_PORT ?? '4318') (for applications)"
        Write-Host "   • OTEL Health:       http://localhost:$($env:OTEL_HEALTH_PORT ?? '13133') (health checks)"
        Write-Host ""
        Write-Host "🔒 Internal services (accessible only within container network):"
        Write-Host "   • Prometheus:        http://prometheus:$($env:PROMETHEUS_INTERNAL_PORT ?? '9090')"
        Write-Host "   • Mimir:             http://mimir:$($env:MIMIR_INTERNAL_PORT ?? '8080')"
        Write-Host "   • Loki:              http://loki:$($env:LOKI_INTERNAL_PORT ?? '3100')"
        Write-Host "   • Tempo:             http://tempo:$($env:TEMPO_INTERNAL_PORT ?? '3200')"
        Write-Host "   • OTEL Self-Monitor: http://otel-collector:$($env:OTEL_METRICS_PORT ?? '8888')"
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
        @{Name = "Grafana"; URL = "http://localhost:$($env:GRAFANA_PORT ?? '3000')/api/health" },
        @{Name = "OTEL-Collector"; URL = "http://localhost:$($env:OTEL_HEALTH_PORT ?? '13133')" }
    )
    
    # Internal services (only accessible if using port forwarding)
    $internalServices = @(
        @{Name = "Prometheus"; Port = "$($env:PROMETHEUS_INTERNAL_PORT ?? '9090')"; Container = "prometheus" },
        @{Name = "Mimir"; Port = "$($env:MIMIR_INTERNAL_PORT ?? '8080')"; Container = "mimir" },
        @{Name = "Loki"; Port = "$($env:LOKI_INTERNAL_PORT ?? '3100')"; Container = "loki" },
        @{Name = "Tempo"; Port = "$($env:TEMPO_INTERNAL_PORT ?? '3200')"; Container = "tempo" }
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
    
    Write-Host ""
    Write-Host "🔒 Internal Services Status:" -ForegroundColor Cyan
    foreach ($service in $internalServices) {
        $containerStatus = docker compose ps --filter "name=$($service.Container)" --format "{{.State}}"
        if ($containerStatus -eq "running") {
            Write-Host "  ✅ $($service.Name): Running (internal port $($service.Port))" -ForegroundColor Green
        }
        else {
            Write-Host "  ❌ $($service.Name): $containerStatus" -ForegroundColor Red
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
    Write-Host "🧪 Running C# OTEL test script..." -ForegroundColor Magenta
    
    # Check if .NET is available
    try {
        dotnet --version | Out-Null
        Write-Host "✅ .NET found" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ .NET not found. Please install .NET SDK" -ForegroundColor Red
        return
    }
    
    # Check if test.cs exists
    if (Test-Path "test.cs") {
        Write-Host "✅ Using C# test script: test.cs" -ForegroundColor Green
    }
    else {
        Write-Host "❌ test.cs not found. Please ensure test.cs exists" -ForegroundColor Red
        return
    }
    
    # Run C# test script
    Write-Host "🚀 Sending test telemetry data..."
    .\test.cs
    
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
        "prometheus\prometheus.yml",
        "mimir\mimir-config.yaml"
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
    $services = @("otel-collector", "loki", "tempo", "prometheus", "mimir")
    
    foreach ($service in $services) {
        Write-Host "--- $service ---" -ForegroundColor Yellow
        docker compose logs --tail 10 $service 2>$null
        Write-Host ""
    }
    
    # Check ports
    Write-Host "🔌 Port Usage:" -ForegroundColor Cyan
    $grafanaPort = $env:GRAFANA_PORT ?? '3000'
    $otelGrpcPort = $env:OTEL_GRPC_PORT ?? '4317'
    $otelHttpPort = $env:OTEL_HTTP_PORT ?? '4318'
    $otelHealthPort = $env:OTEL_HEALTH_PORT ?? '13133'
    $internalPorts = "$($env:LOKI_INTERNAL_PORT ?? '3100'),$($env:TEMPO_INTERNAL_PORT ?? '3200'),$($env:MIMIR_INTERNAL_PORT ?? '8080'),$($env:OTEL_METRICS_PORT ?? '8888'),$($env:PROMETHEUS_INTERNAL_PORT ?? '9090')"
    
    netstat -an | Select-String ":$grafanaPort|:$otelGrpcPort|:$otelHttpPort|:$otelHealthPort" | ForEach-Object { Write-Host "  $_" }
    Write-Host "  Note: Internal ports ($internalPorts) are not exposed externally"
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
