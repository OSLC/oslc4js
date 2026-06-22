#!/bin/sh

# Wait for the database (Fuseki) to be ready before starting the server
JENA_TARGET="${JENA_URL:-http://127.0.0.1:3030/bmm/}"
FUSEKI_HOST_PORT=$(echo "$JENA_TARGET" | sed -E 's/https?:\/\/([^/]+).*/\1/')
echo "Waiting for Fuseki database at http://${FUSEKI_HOST_PORT}/ to be ready..."
until curl -sf -I "http://${FUSEKI_HOST_PORT}/" > /dev/null; do
  sleep 1
done
echo "Fuseki is ready!"

# Start the server in the background
node dist/app.js &
SERVER_PID=$!

# Wait for the server to be responsive
echo "Waiting for BMM server to start..."
until curl -sf -I http://127.0.0.1:3005/ > /dev/null; do
  sleep 1
done

# Run the population script
echo "Server is up! Running database population..."
./testing/populate-eurent.sh

echo ""
echo "============================================================"
echo "Browse the OSLC BMM Server at: ${LDP_BASE:-http://localhost:3005/}"
echo "============================================================"
echo ""

# Bring the server back to foreground to keep container running
wait $SERVER_PID
