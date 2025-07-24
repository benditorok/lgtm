#!/usr/bin/env python3
"""
Test script to send sample telemetry data to OTEL-Collector
"""

import requests
import json
import time
import random
from datetime import datetime

OTEL_HTTP_ENDPOINT = "http://localhost:4318"

def send_trace():
    """Send a sample trace to OTEL-Collector"""
    trace_id = f"{random.randint(1000000000000000, 9999999999999999):016x}{random.randint(1000000000000000, 9999999999999999):016x}"
    span_id = f"{random.randint(10000000, 99999999):08x}{random.randint(10000000, 99999999):08x}"
    
    current_time_ns = int(time.time() * 1_000_000_000)
    
    trace_data = {
        "resourceSpans": [{
            "resource": {
                "attributes": [
                    {"key": "service.name", "value": {"stringValue": "test-service"}},
                    {"key": "service.version", "value": {"stringValue": "1.0.0"}},
                    {"key": "environment", "value": {"stringValue": "development"}}
                ]
            },
            "instrumentationLibrarySpans": [{
                "instrumentationLibrary": {
                    "name": "test-instrumentation",
                    "version": "1.0.0"
                },
                "spans": [{
                    "traceId": trace_id,
                    "spanId": span_id,
                    "name": "test-operation",
                    "kind": 1,  # SPAN_KIND_SERVER
                    "startTimeUnixNano": str(current_time_ns),
                    "endTimeUnixNano": str(current_time_ns + random.randint(1000000, 100000000)),
                    "attributes": [
                        {"key": "http.method", "value": {"stringValue": "GET"}},
                        {"key": "http.url", "value": {"stringValue": "http://example.com/api/test"}},
                        {"key": "http.status_code", "value": {"intValue": "200"}}
                    ],
                    "status": {"code": 1}  # STATUS_CODE_OK
                }]
            }]
        }]
    }
    
    try:
        response = requests.post(
            f"{OTEL_HTTP_ENDPOINT}/v1/traces",
            headers={"Content-Type": "application/json"},
            data=json.dumps(trace_data)
        )
        print(f"Trace sent - Status: {response.status_code}, Trace ID: {trace_id}")
        return response.status_code == 200
    except Exception as e:
        print(f"Failed to send trace: {e}")
        return False

def send_metrics():
    """Send sample metrics to OTEL-Collector"""
    current_time_ns = int(time.time() * 1_000_000_000)
    
    metrics_data = {
        "resourceMetrics": [{
            "resource": {
                "attributes": [
                    {"key": "service.name", "value": {"stringValue": "test-service"}},
                    {"key": "host.name", "value": {"stringValue": "test-host"}}
                ]
            },
            "instrumentationLibraryMetrics": [{
                "instrumentationLibrary": {
                    "name": "test-metrics",
                    "version": "1.0.0"
                },
                "metrics": [
                    {
                        "name": "http_requests_total",
                        "description": "Total number of HTTP requests",
                        "unit": "1",
                        "sum": {
                            "dataPoints": [{
                                "attributes": [
                                    {"key": "method", "value": {"stringValue": "GET"}},
                                    {"key": "status", "value": {"stringValue": "200"}}
                                ],
                                "startTimeUnixNano": str(current_time_ns - 60_000_000_000),
                                "timeUnixNano": str(current_time_ns),
                                "asInt": str(random.randint(100, 1000))
                            }],
                            "aggregationTemporality": 2,  # CUMULATIVE
                            "isMonotonic": True
                        }
                    },
                    {
                        "name": "http_request_duration_seconds",
                        "description": "HTTP request duration in seconds",
                        "unit": "s",
                        "histogram": {
                            "dataPoints": [{
                                "attributes": [
                                    {"key": "method", "value": {"stringValue": "GET"}}
                                ],
                                "startTimeUnixNano": str(current_time_ns - 60_000_000_000),
                                "timeUnixNano": str(current_time_ns),
                                "count": str(random.randint(50, 200)),
                                "sum": random.uniform(10.0, 100.0),
                                "bucketCounts": ["10", "20", "30", "15", "5", "2"],
                                "explicitBounds": [0.1, 0.5, 1.0, 2.0, 5.0]
                            }],
                            "aggregationTemporality": 2  # CUMULATIVE
                        }
                    }
                ]
            }]
        }]
    }
    
    try:
        response = requests.post(
            f"{OTEL_HTTP_ENDPOINT}/v1/metrics",
            headers={"Content-Type": "application/json"},
            data=json.dumps(metrics_data)
        )
        print(f"Metrics sent - Status: {response.status_code}")
        return response.status_code == 200
    except Exception as e:
        print(f"Failed to send metrics: {e}")
        return False

def send_logs():
    """Send sample logs to OTEL-Collector"""
    current_time_ns = int(time.time() * 1_000_000_000)
    
    logs_data = {
        "resourceLogs": [{
            "resource": {
                "attributes": [
                    {"key": "service.name", "value": {"stringValue": "test-service"}},
                    {"key": "host.name", "value": {"stringValue": "test-host"}}
                ]
            },
            "instrumentationLibraryLogs": [{
                "instrumentationLibrary": {
                    "name": "test-logger",
                    "version": "1.0.0"
                },
                "logs": [{
                    "timeUnixNano": str(current_time_ns),
                    "severityNumber": 9,  # INFO
                    "severityText": "INFO",
                    "body": {"stringValue": f"Test log message at {datetime.now()}"},
                    "attributes": [
                        {"key": "log.file", "value": {"stringValue": "test.log"}},
                        {"key": "user.id", "value": {"stringValue": "test-user"}}
                    ]
                }]
            }]
        }]
    }
    
    try:
        response = requests.post(
            f"{OTEL_HTTP_ENDPOINT}/v1/logs",
            headers={"Content-Type": "application/json"},
            data=json.dumps(logs_data)
        )
        print(f"Logs sent - Status: {response.status_code}")
        return response.status_code == 200
    except Exception as e:
        print(f"Failed to send logs: {e}")
        return False

def main():
    """Main function to test all telemetry types"""
    print("Testing OTEL-Collector endpoints...")
    print(f"OTEL HTTP Endpoint: {OTEL_HTTP_ENDPOINT}")
    print("-" * 50)
    
    # Test traces
    print("Sending traces...")
    for i in range(3):
        send_trace()
        time.sleep(1)
    
    print("\nSending metrics...")
    send_metrics()
    
    print("\nSending logs...")
    for i in range(2):
        send_logs()
        time.sleep(1)
    
    print("\nTest completed!")
    print("\nCheck Grafana at http://localhost:3000 (admin/admin) to see the data")

if __name__ == "__main__":
    main()
