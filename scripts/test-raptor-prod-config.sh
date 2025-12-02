#!/bin/bash
set -e

# Test script for validating Raptor production configuration locally
# This script builds a production release and checks if it starts successfully

echo "========================================================"
echo "Testing Raptor Production Configuration"
echo "========================================================"

# Set default environment variables for testing
export KAFKA_BROKERS="${KAFKA_BROKERS:-localhost:9092}"
export EVENT_STREAM_TOPIC="${EVENT_STREAM_TOPIC:-event-stream}"
export DEAD_LETTER_TOPIC="${DEAD_LETTER_TOPIC:-streaming-dead-letters}"
export REDIS_HOST="${REDIS_HOST:-localhost}"
export REDIS_PORT="${REDIS_PORT:-6379}"

echo ""
echo "Environment Variables:"
echo "  KAFKA_BROKERS: $KAFKA_BROKERS"
echo "  EVENT_STREAM_TOPIC: $EVENT_STREAM_TOPIC"
echo "  DEAD_LETTER_TOPIC: $DEAD_LETTER_TOPIC"
echo "  REDIS_HOST: $REDIS_HOST"
echo "  REDIS_PORT: $REDIS_PORT"
echo ""

# Clean previous builds
echo "Step 1: Cleaning previous builds..."
env MIX_ENV=prod mix clean --only-deps
rm -rf _build/prod/rel/raptor

# Get dependencies
echo ""
echo "Step 2: Getting production dependencies..."
env MIX_ENV=prod mix deps.get

# Compile
echo ""
echo "Step 3: Compiling for production..."
env MIX_ENV=prod mix compile || {
    echo "ERROR: Compilation failed!"
    exit 1
}

# Build release
echo ""
echo "Step 4: Building production release..."
env MIX_ENV=prod mix release raptor || {
    echo "ERROR: Release build failed!"
    exit 1
}

# Check if runtime.exs is included in the release
echo ""
echo "Step 5: Verifying runtime.exs is included..."
if [ -f "_build/prod/rel/raptor/releases/1.0.0/runtime.exs" ]; then
    echo "✓ runtime.exs found in release"
else
    echo "✗ WARNING: runtime.exs not found in release!"
    echo "  Expected location: _build/prod/rel/raptor/releases/1.0.0/runtime.exs"
fi

# Check sys.config
echo ""
echo "Step 6: Checking sys.config..."
if [ -f "_build/prod/rel/raptor/releases/1.0.0/sys.config" ]; then
    echo "✓ sys.config found"
    echo ""
    echo "Checking for brook configuration in sys.config:"
    if grep -q "brook" "_build/prod/rel/raptor/releases/1.0.0/sys.config"; then
        echo "  ✓ brook config found in sys.config"
    else
        echo "  ✗ brook config NOT found in sys.config (expected - should be in runtime.exs)"
    fi
else
    echo "✗ sys.config not found!"
fi

echo ""
echo "========================================================"
echo "Build completed successfully!"
echo "========================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Test startup in console mode (requires Kafka & Redis running):"
echo "   _build/prod/rel/raptor/bin/raptor console"
echo ""
echo "2. Test startup as daemon (requires Kafka & Redis running):"
echo "   _build/prod/rel/raptor/bin/raptor start"
echo "   _build/prod/rel/raptor/bin/raptor logs"
echo "   _build/prod/rel/raptor/bin/raptor stop"
echo ""
echo "3. Look for these log messages on startup:"
echo "   - 'Runtime Configuration Loaded (MIX_ENV=prod)'"
echo "   - 'DeadLetter.Application starting...'"
echo "   - 'Raptor.Application starting...'"
echo "   - 'Raptor Brook configuration:'"
echo "   - 'DeadLetter driver configuration found:'"
echo ""
echo "4. If startup fails, check logs for detailed error messages"
echo ""
echo "========================================================"
