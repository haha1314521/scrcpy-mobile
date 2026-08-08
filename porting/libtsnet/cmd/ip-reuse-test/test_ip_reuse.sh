#!/bin/bash

# Test script for IP reuse consistency
echo "=== Tailscale IP Reuse Test ==="

# Check if auth key is provided
if [ -z "$TSNET_AUTH_KEY" ]; then
    echo "❌ Error: Please set TSNET_AUTH_KEY environment variable"
    echo "Usage: TSNET_AUTH_KEY='your-auth-key' ./test_ip_reuse.sh"
    exit 1
fi

# Set default values if not provided
export TSNET_HOSTNAME=${TSNET_HOSTNAME:-"scrcpy-ip-test-$(date +%s)"}
export TSNET_STATE_DIR=${TSNET_STATE_DIR:-"/tmp/tsnet-ip-reuse-test-$(date +%s)"}

echo "🔧 Test Configuration:"
echo "   Hostname: $TSNET_HOSTNAME"
echo "   State Dir: $TSNET_STATE_DIR"
echo ""

# Clean up any existing test state
echo "🧹 Cleaning up any existing test state..."
rm -rf "$TSNET_STATE_DIR"

# Build and run the test
echo "�� Building test..."
go build -o ip-reuse-test main.go

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "🚀 Running IP reuse test..."
echo ""
./ip-reuse-test

# Cleanup
echo ""
echo "🧹 Cleaning up test files..."
rm -f ip-reuse-test
rm -rf "$TSNET_STATE_DIR"

echo "✅ Test completed!" 