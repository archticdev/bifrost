#!/bin/sh

# Read the file provided as argument
input_file="$1"
cert="$2"
verbose=

keepalive_interval=60
keepalive_count=300

# Check if yq is available, if not install it
if ! command -v yq > /dev/null 2>&1; then
    echo "yq not found, installing..."
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    chmod +x /usr/local/bin/yq
fi

# Create .ssh directory if it doesn't exist
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Parse remote section and create -L (local forward) tunnels
echo "Setting up remote forward tunnels (-L)..."
if yq eval '.remote' "$input_file" | grep -q .; then
    services=$(yq eval '.remote | keys | .[]' "$input_file")
    for service in $services; do
        if [ -n "$service" ]; then
            # Get local_host and remote_host with defaults
            local_host=$(yq eval ".remote.\"$service\".local_host // \"0.0.0.0\"" "$input_file")
            remote_host=$(yq eval ".remote.\"$service\".remote_host // \"localhost\"" "$input_file")

            # Process multiple port mappings
            port_mappings=$(yq eval ".remote.\"$service\".local_to_remote_ports | keys | .[]" "$input_file")
            for local_port in $port_mappings; do
                remote_port=$(yq eval ".remote.\"$service\".local_to_remote_ports.\"$local_port\"" "$input_file")

                tunnel_spec="$local_host:$local_port:$remote_host:$remote_port"
                echo "Creating -L tunnel for $service: $tunnel_spec"

                autossh -M 0 $verbose \
                    -o StrictHostKeyChecking=no \
                    -o ServerAliveInterval=60 \
                    -o ServerAliveCountMax=3 \
                    -o TCPKeepAlive=yes \
                    -o ExitOnForwardFailure=yes \
                    -o LogLevel=ERROR \
                    -i "$cert" -N -L "$tunnel_spec" \
                    $SSH_USER@$SSH_HOST &
            done
        fi
    done
fi

# Parse local section and create -R (reverse) tunnels
echo "Setting up reverse tunnels (-R)..."
if yq eval '.local' "$input_file" | grep -q .; then
    services=$(yq eval '.local | keys | .[]' "$input_file")
    for service in $services; do
        if [ -n "$service" ]; then
            # Get remote_host and local_host with defaults
            remote_host=$(yq eval ".local.\"$service\".remote_host // \"localhost\"" "$input_file")
            local_host=$(yq eval ".local.\"$service\".local_host // \"0.0.0.0\"" "$input_file")

            # Process multiple port mappings
            port_mappings=$(yq eval ".local.\"$service\".local_to_remote_ports | keys | .[]" "$input_file")
            for local_port in $port_mappings; do
                remote_port=$(yq eval ".local.\"$service\".local_to_remote_ports.\"$local_port\"" "$input_file")

                tunnel_spec="$remote_host:$remote_port:$local_host:$local_port"
                echo "Creating -R tunnel for $service: $tunnel_spec"

                autossh -M 0 $verbose \
                    -o StrictHostKeyChecking=no \
                    -o ServerAliveInterval=60 \
                    -o ServerAliveCountMax=3 \
                    -o TCPKeepAlive=yes \
                    -o ExitOnForwardFailure=yes \
                    -o LogLevel=ERROR \
                    -i "$cert" -N -R "$tunnel_spec" \
                    $SSH_USER@$SSH_HOST &
            done
        fi
    done
fi

echo "All tunnels created. Waiting..."
# Wait for all background SSH processes
wait
