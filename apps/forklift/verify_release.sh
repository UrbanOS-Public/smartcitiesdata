#!/bin/bash

set -e

echo "=== Verifying Forklift Release Configuration ==="

echo "1. Checking mix.exs releases configuration..."
if grep -q "releases:" mix.exs; then
    echo "✓ releases section found in mix.exs"
else
    echo "✗ releases section missing in mix.exs"
    exit 1
fi

echo "2. Checking Dockerfile uses mix release..."
if grep -q "mix release forklift" Dockerfile; then
    echo "✓ Dockerfile uses mix release instead of distillery"
else
    echo "✗ Dockerfile still uses distillery"
    exit 1
fi

echo "3. Testing release compilation..."
export MIX_ENV=prod
mix deps.get --only prod > /dev/null 2>&1
mix compile --warnings-as-errors

echo "4. Attempting to build release..."
mix release forklift --overwrite

if [ -d "_build/prod/rel/forklift" ]; then
    echo "✓ Release built successfully"
    echo "✓ Release directory exists: _build/prod/rel/forklift"
else
    echo "✗ Release build failed - directory not found"
    exit 1
fi

echo "5. Checking release executable..."
if [ -f "_build/prod/rel/forklift/bin/forklift" ]; then
    echo "✓ Release executable exists"
else
    echo "✗ Release executable not found"
    exit 1
fi

echo ""
echo "=== Release Verification Complete ==="
echo "✓ All checks passed!"
echo "✓ Migration from Distillery to built-in mix release successful"
echo ""
echo "To deploy:"
echo "  1. Build Docker image: docker build -t forklift:latest ."
echo "  2. Run with: docker run forklift:latest"