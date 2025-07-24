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

const string ServiceName = "LGTM";
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
    .AddSource(ActivitySourceName)
    .AddOtlpExporter(options =>
    {
        options.Endpoint = new Uri("http://127.0.0.1:4318");
        options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.HttpProtobuf;
    })
    .Build();

var meterProvider = Sdk.CreateMeterProviderBuilder()
    .SetResourceBuilder(resourceBuilder)
    .AddMeter(MeterName)
    .AddOtlpExporter(options =>
    {
        options.Endpoint = new Uri("http://127.0.0.1:4318");
        options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.HttpProtobuf;
    })
    .Build();


var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddOpenTelemetry(logging =>
    {
        logging.AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri("http://127.0.0.1:4318");
            options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.HttpProtobuf;
        });
    });
});

var logger = loggerFactory.CreateLogger<Program>();

using (var activity = ActivitySource.StartActivity("SayHello"))
{
    activity?.SetTag("foo", 1);
    activity?.SetTag("bar", "Hello, World!");
    activity?.SetTag("baz", new int[] { 1, 2, 3 });
    activity?.SetStatus(ActivityStatusCode.Ok);
}


TestCounter.Add(1, new("name", "apple"), new("color", "red"));
TestCounter.Add(2, new("name", "lemon"), new("color", "yellow"));
TestCounter.Add(1, new("name", "lemon"), new("color", "yellow"));

logger.LogInformation("Hello, World! This is a test log message.");

tracingProvider.Dispose();
meterProvider.Dispose();
loggerFactory.Dispose();