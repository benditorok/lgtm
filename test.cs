#!/usr/bin/dotnet run

#:package OpenTelemetry@1.12.0
#:package OpenTelemetry.Exporter.OpenTelemetryProtocol@1.12.0

using OpenTelemetry;
using OpenTelemetry.Exporter.OpenTelemetryProtocol;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;
using OpenTelemetry.Logs;

private const string ServiceName = "LGTM";
private const string ActivitySourceName = "TestingSource";
private const string MeterName = "TestMeter";
private const string CounterName = "TestCounter";

private static readonly ActivitySource ActivitySource = new ActivitySource(SourceName);
private static readonly Meter TestMeter = new(MeterName);
private static readonly Counter<long> TestCounter = TestMeter.CreateCounter<long>(CounterName);

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
        options.Endpoint = new Uri("http://localhost:4318");
        options.Protocol = OtlpExportProtocol.HttpProtobuf;
    })
    .Build();

var meterProvider = Sdk.CreateMeterProviderBuilder()
    .SetResourceBuilder(resourceBuilder)
    .AddMeter(MeterName)
    .AddOtlpExporter(options =>
    {
        options.Endpoint = new Uri("http://localhost:4318");
        options.Protocol = OtlpExportProtocol.HttpProtobuf;
    })
    .Build();


var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddOpenTelemetry(logging =>
    {
        logging.AddConsoleExporter();
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