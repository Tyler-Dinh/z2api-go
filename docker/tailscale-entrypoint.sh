#!/bin/sh
set -e

# Check if TS_AUTH_KEY is set
if [ -z "${TS_AUTH_KEY}" ]; then
    echo "ERROR: TS_AUTH_KEY environment variable is required"
    echo "Please generate an ephemeral auth key from: https://login.tailscale.com/admin/settings/keys"
    exit 1
fi

# Set default values if not provided
TS_HOSTNAME="${TS_HOSTNAME:-z2api-go}"
TS_EXTRA_ARGS="${TS_EXTRA_ARGS:-}"
TS_STATE_DIR="${TS_STATE_DIR:-/var/lib/tailscale}"

# Create state directory if it doesn't exist
mkdir -p "${TS_STATE_DIR}"

echo "Starting Tailscale daemon..."
tailscaled --state="${TS_STATE_DIR}/tailscaled.state" --socket=/var/run/tailscale/tailscaled.sock &
TAILSCALED_PID=$!

# Wait for tailscaled to start with retry logic
echo "Waiting for tailscaled to be ready..."
RETRY_COUNT=0
MAX_RETRIES=30
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if tailscale status >/dev/null 2>&1; then
        echo "✓ Tailscaled is ready"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 1
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "ERROR: Tailscaled failed to start within ${MAX_RETRIES} seconds"
    exit 1
fi

echo "Connecting to Tailscale network..."
echo "  Hostname: ${TS_HOSTNAME}"
echo "  State Dir: ${TS_STATE_DIR}"

# Authenticate with Tailscale using ephemeral key
# Note: TS_EXTRA_ARGS is intentionally not quoted to allow word splitting
# for multiple arguments (e.g., "--accept-dns=true --ssh")
# This is safe because the user controls the environment variable
tailscale up \
    --authkey="${TS_AUTH_KEY}" \
    --hostname="${TS_HOSTNAME}" \
    --accept-routes \
    ${TS_EXTRA_ARGS}

echo "✓ Tailscale connected successfully!"
echo "  Status:"
tailscale status

# Monitor tailscaled process and restart if it crashes
while true; do
    if ! kill -0 $TAILSCALED_PID 2>/dev/null; then
        echo "ERROR: Tailscaled process (PID $TAILSCALED_PID) has crashed"
        exit 1
    fi
    sleep 10
done
