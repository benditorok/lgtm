#!/usr/bin/env python3
"""
Basic test script for OTEL-Collector endpoints
This is a fallback script used when the comprehensive test_otel.py is not available.
"""

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
    print("✅ Basic test completed! Check Grafana at http://localhost:3000")
