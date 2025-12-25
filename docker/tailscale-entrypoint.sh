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

# Validate TS_EXTRA_ARGS if provided using whitelist approach
if [ -n "${TS_EXTRA_ARGS}" ]; then
    # Check for any characters that aren't typical Tailscale flag characters
    # Allowed: letters, numbers, hyphens, equals, commas, dots, colons, slashes, spaces
    # This whitelist approach is more secure than blacklisting specific characters
    if ! echo "${TS_EXTRA_ARGS}" | grep -qE '^[a-zA-Z0-9 =,.:/-]+$'; then
        echo "ERROR: TS_EXTRA_ARGS contains invalid characters"
        echo "Only alphanumeric characters and these symbols are allowed: - = , . : / (space)"
        echo "Examples of valid usage:"
        echo "  --accept-dns=true"
        echo "  --advertise-tags=tag:service,tag:production"
        echo "  --advertise-routes=10.0.0.0/24"
        exit 1
    fi
    echo "  Extra Args: ${TS_EXTRA_ARGS}"
fi

# Authenticate with Tailscale using ephemeral key
# Note: TS_EXTRA_ARGS is intentionally not quoted to allow word splitting
# for multiple arguments. The variable is validated above using a whitelist
# of safe characters to prevent injection attacks.
tailscale up \
    --authkey="${TS_AUTH_KEY}" \
    --hostname="${TS_HOSTNAME}" \
    --accept-routes \
    ${TS_EXTRA_ARGS}

echo "✓ Tailscale connected successfully!"
echo "  Status:"
tailscale status

# Monitor tailscaled process
# Exit if daemon crashes - Docker will restart the container if restart policy is set
while true; do
    if ! kill -0 $TAILSCALED_PID 2>/dev/null; then
        echo "ERROR: Tailscaled process (PID $TAILSCALED_PID) has crashed"
        echo "Container will exit and restart if restart policy is configured"
        exit 1
    fi
    sleep 10
done
