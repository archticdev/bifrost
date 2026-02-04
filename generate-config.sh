#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVENV_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REMOTE_YML="$SCRIPT_DIR/config.yml"
OUTPUT_FILE="$SCRIPT_DIR/docker-compose.yml"

# Function to run yq - tries native yq first, then Docker
run_yq() {
    if command -v yq &> /dev/null; then
        yq "$@"
    elif command -v docker &> /dev/null; then
        docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq "$@" /workdir/config.yml
    else
        echo "Error: yq is not installed and Docker is not available."
        echo "Please install yq:"
        echo "  brew install yq"
        echo "or ensure Docker is running."
        exit 1
    fi
}

# Check if config.yml exists
if [ ! -f "$REMOTE_YML" ]; then
    echo "Error: config.yml not found at $REMOTE_YML"
    exit 1
fi

echo "Generating bifrost configuration from $REMOTE_YML..."

# Extract service names from remote section
if command -v yq &> /dev/null; then
    services=$(yq eval '.remote | keys | .[]' "$REMOTE_YML" 2>/dev/null || echo "")
else
    # Use Docker-based yq
    services=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval '.remote | keys | .[]' /workdir/config.yml 2>/dev/null || echo "")
fi

# Build aliases array
aliases=""
ports=""

if [ -n "$services" ]; then
    for service in $services; do
        # Add alias
        if [ -z "$aliases" ]; then
            aliases="          - $service"
        else
            aliases="$aliases\n          - $service"
        fi

        # Extract port mappings from local_to_remote_ports
        if command -v yq &> /dev/null; then
            port_keys=$(yq eval ".remote.\"$service\".local_to_remote_ports | keys | .[]" "$REMOTE_YML" 2>/dev/null)
        else
            port_keys=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval ".remote.\"$service\".local_to_remote_ports | keys | .[]" /workdir/config.yml 2>/dev/null)
        fi

        for local_port in $port_keys; do
            # Add port mapping
            if [ -z "$ports" ]; then
                ports="      - \"$local_port:$local_port\""
            else
                ports="$ports\n      - \"$local_port:$local_port\""
            fi
        done
    done
fi

# Generate the docker-compose.bifrost.yml file
cat > "$OUTPUT_FILE" << 'EOF'
name: bifrost
include:
  - ../compositions/shared/docker-compose.network.yml
services:
  bifrost:
    extends:
      file: docker-compose.bifrost-template.yml
      service: bifrost
    networks:
      company:
        aliases:
EOF

# Append aliases
if [ -n "$aliases" ]; then
    echo -e "$aliases" >> "$OUTPUT_FILE"
else
    echo "          # No remote services configured" >> "$OUTPUT_FILE"
fi

# Append ports section
if [ -n "$ports" ]; then
    echo "    ports:" >> "$OUTPUT_FILE"
    echo -e "$ports" >> "$OUTPUT_FILE"
fi

echo "✓ Generated $OUTPUT_FILE with the following configuration:"
echo ""
echo "Network aliases:"
if [ -n "$services" ]; then
    for service in $services; do
        # Extract port mappings from local_to_remote_ports
        if command -v yq &> /dev/null; then
            port_keys=$(yq eval ".remote.\"$service\".local_to_remote_ports | keys | .[]" "$REMOTE_YML" 2>/dev/null)
        else
            port_keys=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval ".remote.\"$service\".local_to_remote_ports | keys | .[]" /workdir/config.yml 2>/dev/null)
        fi

        # Build port list showing both sides of mapping
        port_list=""
        for local_port in $port_keys; do
            if command -v yq &> /dev/null; then
                remote_port=$(yq eval ".remote.\"$service\".local_to_remote_ports.\"$local_port\"" "$REMOTE_YML" 2>/dev/null)
            else
                remote_port=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval ".remote.\"$service\".local_to_remote_ports.\"$local_port\"" /workdir/config.yml 2>/dev/null)
            fi

            if [ -z "$port_list" ]; then
                port_list="$local_port:$remote_port"
            else
                port_list="$port_list, $local_port:$remote_port"
            fi
        done

        echo "  - $service (ports: $port_list)"
    done
else
    echo "  (none)"
fi
echo ""
echo "Done!"
