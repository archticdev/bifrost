#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVENV_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Accept config file as parameter
CONFIG_FILE="${1:-config.yml}"

# Resolve config file path (allow absolute or relative to script dir)
if [[ "$CONFIG_FILE" = /* ]]; then
    CONFIG_YML="$CONFIG_FILE"
else
    CONFIG_YML="$SCRIPT_DIR/$CONFIG_FILE"
fi

TEMPLATE_FILE="$SCRIPT_DIR/docker-compose.template.yml"
OUTPUT_FILE="$SCRIPT_DIR/docker-compose.yml"

# Function to run yq - tries native yq first, then Docker
run_yq() {
    if command -v yq &> /dev/null; then
        yq "$@"
    elif command -v docker &> /dev/null; then
        docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq "$@"
    else
        echo "Error: yq is not installed and Docker is not available."
        echo "Please install yq:"
        echo "  brew install yq"
        echo "or ensure Docker is running."
        exit 1
    fi
}

# Check if config.yml exists
if [ ! -f "$CONFIG_YML" ]; then
    echo "Error: config.yml not found at $CONFIG_YML"
    exit 1
fi

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: template file not found at $TEMPLATE_FILE"
    exit 1
fi

echo "Generating bifrost configuration from $CONFIG_YML..."

# Extract values from config.yml
if command -v yq &> /dev/null; then
    NETWORK=$(yq eval '.docker.network' "$CONFIG_YML" 2>/dev/null || echo "common")
    SSH_IDENTITY_FILE=$(yq eval '.ssh.identity_file' "$CONFIG_YML" 2>/dev/null || echo "~/.ssh/id_rsa")
    SSH_USER=$(yq eval '.ssh.user' "$CONFIG_YML" 2>/dev/null || echo "")
    SSH_HOST=$(yq eval '.ssh.host' "$CONFIG_YML" 2>/dev/null || echo "")
    services=$(yq eval '.remote | keys | .[]' "$CONFIG_YML" 2>/dev/null || echo "")
else
    NETWORK=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval '.docker.network' /workdir/config.yml 2>/dev/null || echo "common")
    SSH_IDENTITY_FILE=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval '.ssh.identity_file' /workdir/config.yml 2>/dev/null || echo "~/.ssh/id_rsa")
    SSH_USER=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval '.ssh.user' /workdir/config.yml 2>/dev/null || echo "")
    SSH_HOST=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval '.ssh.host' /workdir/config.yml 2>/dev/null || echo "")
    services=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval '.remote | keys | .[]' /workdir/config.yml 2>/dev/null || echo "")
fi

# Build aliases array
aliases=""
ports=""

if [ -n "$services" ]; then
    for service in $services; do
        # Add alias with proper indentation
        if [ -z "$aliases" ]; then
            aliases="          - $service"
        else
            aliases="$aliases\n          - $service"
        fi

        # Extract port mappings from local_to_remote_ports
        if command -v yq &> /dev/null; then
            port_keys=$(yq eval ".remote.\"$service\".local_to_remote_ports | keys | .[]" "$CONFIG_YML" 2>/dev/null)
        else
            port_keys=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval ".remote.\"$service\".local_to_remote_ports | keys | .[]" /workdir/config.yml 2>/dev/null)
        fi

        for local_port in $port_keys; do
            # Add port mapping
            if [ -z "$ports" ]; then
                ports="    ports:\n      - \"$local_port:$local_port\""
            else
                ports="$ports\n      - \"$local_port:$local_port\""
            fi
        done
    done
fi

# Set default values if empty
if [ -z "$aliases" ]; then
    aliases="          # No remote services configured"
fi

if [ -z "$ports" ]; then
    ports="    # No ports configured"
fi

# Read template and perform substitutions
template_content=$(cat "$TEMPLATE_FILE")

# Perform substitutions using parameter expansion
output_content="$template_content"
output_content="${output_content//\{\{NETWORK\}\}/$NETWORK}"
output_content="${output_content//\{\{SSH_IDENTITY_FILE\}\}/$SSH_IDENTITY_FILE}"
output_content="${output_content//\{\{SSH_USER\}\}/$SSH_USER}"
output_content="${output_content//\{\{SSH_HOST\}\}/$SSH_HOST}"

# Handle multi-line replacements using awk
output_content=$(echo "$output_content" | awk -v aliases="$aliases" '{
    if ($0 ~ /{{ALIASES}}/) {
        system("printf \"%b\\n\" \"" aliases "\"")
    } else {
        print $0
    }
}')

output_content=$(echo "$output_content" | awk -v ports="$ports" '{
    if ($0 ~ /{{PORTS}}/) {
        system("printf \"%b\\n\" \"" ports "\"")
    } else {
        print $0
    }
}')

# Write output
echo "$output_content" > "$OUTPUT_FILE"

echo "✓ Generated $OUTPUT_FILE with the following configuration:"
echo ""
echo "Network: $NETWORK"
echo "SSH User: $SSH_USER"
echo "SSH Host: $SSH_HOST"
echo "SSH Identity File: $SSH_IDENTITY_FILE"
echo ""
echo "Network aliases:"
if [ -n "$services" ]; then
    for service in $services; do
        # Extract port mappings from local_to_remote_ports
        if command -v yq &> /dev/null; then
            port_keys=$(yq eval ".remote.\"$service\".local_to_remote_ports | keys | .[]" "$CONFIG_YML" 2>/dev/null)
        else
            port_keys=$(docker run --rm -i -v "$SCRIPT_DIR:/workdir" mikefarah/yq eval ".remote.\"$service\".local_to_remote_ports | keys | .[]" /workdir/config.yml 2>/dev/null)
        fi

        # Build port list showing both sides of mapping
        port_list=""
        for local_port in $port_keys; do
            if command -v yq &> /dev/null; then
                remote_port=$(yq eval ".remote.\"$service\".local_to_remote_ports.\"$local_port\"" "$CONFIG_YML" 2>/dev/null)
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
