#!/bin/bash
set -e

echo "Starting OmniRoute..."

# Start OmniRoute on internal port
PORT=20127 DASHBOARD_PORT=20127 API_PORT=20127 node dev/run-standalone.mjs &
OMNI_PID=$!

# Wait for OmniRoute to be ready
echo "Waiting for OmniRoute to start..."
for i in $(seq 1 30); do
    if curl -s http://127.0.0.1:20127/api/monitoring/health > /dev/null 2>&1; then
        echo "OmniRoute is ready."
        break
    fi
    sleep 2
done

echo "Starting nginx..."
exec nginx -g "daemon off;"
