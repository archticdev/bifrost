# Bifrost Service

The bifrost service creates SSH tunnels to remote services defined in `config.yml`.

## How It Works

1. The bifrost container connects to a remote EC2 instance via SSH
2. It creates local forward tunnels (-L) for services listed in the `remote` section
3. It creates reverse tunnels (-R) for services listed in the `local` section
4. Network aliases are automatically configured so services can connect using their service names

## Configuration

### config.yml

Define remote services in the root `config.yml` file:

```yaml
remote:
  payments:
    local_to_remote_ports:
      "9001": "9001"
      "4000": "4000"  # Multiple ports supported
```

**Format:**
- `local_to_remote_ports`: A map of local ports to remote ports (required)
  - Each entry maps a local port (key) to a remote port (value)
  - Multiple port mappings are supported per service
- `local_host`: The interface to bind on locally (optional, defaults to `0.0.0.0`)
- `remote_host`: The host on the EC2 instance to forward to (optional, defaults to `localhost`)

**Example with custom hosts:**
```yaml
remote:
  rabbitmq:
    local_host: rabbitmq      # Override default
    remote_host: 0.0.0.0      # Override default
    local_to_remote_ports:
      "5672": "5672"
```

**Example with multiple ports:**
```yaml
remote:
  grafana:
    local_to_remote_ports:
      "3000": "3000"
      "3001": "3001"
      "9090": "9090"
```

### Local Services (Reverse Tunnels)

For services running locally that need to be accessible from the EC2 instance:

```yaml
local:
  web-gateway:
    local_to_remote_ports:
      "8080": "8080"
```

**Defaults for local section:**
- `local_host`: Defaults to `0.0.0.0`
- `remote_host`: Defaults to `localhost`

### Generating the Docker Compose File

The `docker-compose.bifrost.yml` file is **generated** from the template and should not be edited manually.

To generate/update it:

```bash
make bifrost-config
```

This script:
1. Reads `config.yml`
2. Extracts service names from the `remote` section
3. Generates `docker-compose.bifrost.yml` with:
   - Network aliases for each remote service
   - Port mappings for each service

## Usage

After generating the config:

```bash
cd compositions
docker-compose -f docker-compose.bifrost.yml up -d
```

Now other services can connect to remote services using their service names:
- `payments:9001` instead of `localhost:9001`
- `grafana:3000` instead of `localhost:3000`
- etc.

## Files

- `Dockerfile` - Bifrost container image with SSH and autossh
- `bifrost.sh` - Script that creates SSH tunnels based on config.yml
- `docker-compose.bifrost-template.yml` - Template for the bifrost service
- `generate-config.sh` - Script to generate docker-compose.bifrost.yml
- `Makefile` - Make targets for bifrost configuration
- `README.md` - This file
