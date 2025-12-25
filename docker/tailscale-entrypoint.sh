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

# Wait for tailscaled to start
sleep 2

echo "Connecting to Tailscale network..."
echo "  Hostname: ${TS_HOSTNAME}"
echo "  State Dir: ${TS_STATE_DIR}"

# Authenticate with Tailscale using ephemeral key
tailscale up \
    --authkey="${TS_AUTH_KEY}" \
    --hostname="${TS_HOSTNAME}" \
    --accept-routes \
    ${TS_EXTRA_ARGS}

echo "✓ Tailscale connected successfully!"
echo "  Status:"
tailscale status

# Keep the container running and monitor tailscaled
wait $TAILSCALED_PID
