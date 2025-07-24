#!/usr/bin/dotnet run

#:package OpenTelemetry@1.12.0
#:package OpenTelemetry.Exporter.OpenTelemetryProtocol@1.12.0

using System.Diagnostics;
using System.Diagnostics.Metrics;
using Microsoft.Extensions.Logging;
using OpenTelemetry;
using OpenTelemetry.Logs;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;

Console.WriteLine("🔧 Initializing OpenTelemetry providers...");

const string ServiceName = "LGTMTesting";
const string ActivitySourceName = "TestingSource";
const string MeterName = "TestMeter";
const string CounterName = "TestCounter";

ActivitySource ActivitySource = new ActivitySource(ActivitySourceName);
Meter TestMeter = new(MeterName);
Counter<long> TestCounter = TestMeter.CreateCounter<long>(CounterName);

var resourceBuilder = ResourceBuilder.CreateDefault()
    .AddService(ServiceName, serviceVersion: "0.1.0", serviceInstanceId: Environment.MachineName)
    .AddAttributes(new Dictionary<string, object>
    {
        { "environment", "development" },
        { "host.name", Environment.MachineName }
    });

var tracingProvider = Sdk.CreateTracerProviderBuilder()
    .SetResourceBuilder(resourceBuilder)
    .AddSource(ActivitySourceName)
    .AddOtlpExporter(options =>
    {
        options.Endpoint = new Uri("http://127.0.0.1:4318/v1/traces");
        options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.HttpProtobuf;
        options.ExportProcessorType = OpenTelemetry.ExportProcessorType.Simple; // Force immediate export
    })
    .Build();

var meterProvider = Sdk.CreateMeterProviderBuilder()
    .SetResourceBuilder(resourceBuilder)
    .AddMeter(MeterName)
    .AddOtlpExporter(options =>
    {
        options.Endpoint = new Uri("http://127.0.0.1:4318/v1/metrics");
        options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.HttpProtobuf;
        options.ExportProcessorType = OpenTelemetry.ExportProcessorType.Simple; // Force immediate export
    })
    .Build();


var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddOpenTelemetry(logging =>
    {

        logging
            .SetResourceBuilder(resourceBuilder)
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri("http://127.0.0.1:4318/v1/logs");
                options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.HttpProtobuf;
                options.ExportProcessorType = OpenTelemetry.ExportProcessorType.Simple; // Force immediate export
            });
    });
});

var logger = loggerFactory.CreateLogger<Program>();

Console.WriteLine("🚀 Sending telemetry data to OTEL Collector...");

// Create some traces/spans
using (var activity = ActivitySource.StartActivity("TestOperation"))
{
    activity?.SetTag("operation.name", "test-operation");
    activity?.SetTag("user.id", "test-user");

    Console.WriteLine("📊 Creating traces...");

    using (var childActivity = ActivitySource.StartActivity("ChildOperation"))
    {
        childActivity?.SetTag("child.operation", "data-processing");

        // Simulate some work
        Thread.Sleep(100);

        // Add some metrics
        TestCounter.Add(1, new("name", "apple"), new("color", "red"));
        TestCounter.Add(2, new("name", "lemon"), new("color", "yellow"));
        TestCounter.Add(1, new("name", "lemon"), new("color", "yellow"));

        Console.WriteLine("📈 Creating metrics...");

        // Add some logs
        logger.LogInformation("Hello, World! This is a test log message from C#.");
        logger.LogWarning("This is a warning message with context: {Operation}", "TestOperation");
        logger.LogError("This is an error message for testing purposes");

        Console.WriteLine("📋 Creating logs...");

        Thread.Sleep(50);
    }

    Thread.Sleep(100);
}

Console.WriteLine("⏳ Flushing telemetry data...");

// Add a delay to ensure data is sent before disposing
Thread.Sleep(2000);

Console.WriteLine("✅ Telemetry data sent! Check Grafana at http://localhost:3000");

tracingProvider.Dispose();
meterProvider.Dispose();
loggerFactory.Dispose();