# Bifrost

```
╔═════════════════════════════════════════════════════════════════════╗
║                    The Bridge Between Realms                        ║
║          Connecting Local Development to Remote Services            ║
╚═════════════════════════════════════════════════════════════════════╝
```

## What is Bifrost?

Bifrost is an SSH tunneling tool that creates secure bridges between your local development environment and remote services. Named after the rainbow bridge in Norse mythology, Bifrost automates the creation and management of bidirectional SSH tunnels, making it easy to:

- **Access remote services locally**: Forward remote service ports to your local machine (using SSH `-L` tunnels)
- **Expose local services remotely**: Make your local development services accessible from remote hosts (using SSH `-R` reverse tunnels)
- **Simplify development workflows**: Connect to remote databases, APIs, and services without complex networking or VPN configurations
- **Maintain persistent connections**: Automatically reconnect tunnels if connections drop using `autossh`

## Key Features

- 🔒 **Secure SSH tunneling** with automatic reconnection
- 🔄 **Bidirectional tunnels** (both local forward and reverse)
- 📝 **YAML-based configuration** for easy service management
- 🐳 **Docker-integrated** for seamless container networking
- 🎯 **Multiple port mappings** per service
- 🌐 **Network aliases** for service discovery

## How It Works

1. The bifrost container connects to a remote host (e.g., EC2 instance) via SSH
2. It creates **local forward tunnels (-L)** for services listed in the `remote` section, making remote services accessible locally
3. It creates **reverse tunnels (-R)** for services listed in the `local` section, exposing local services to the remote host
4. Network aliases are automatically configured so other Docker services can connect using service names instead of localhost ports

### Use Cases

- **Database Access**: Connect to remote PostgreSQL, MySQL, or MongoDB instances as if they were running locally
- **API Development**: Access staging/production APIs from your local development environment
- **Webhook Testing**: Expose local services to receive webhooks from external services
- **Microservices Development**: Access remote microservices while developing locally
- **Secure Remote Access**: Bypass firewalls and access services in private networks

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
make config
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
make [bifrost|restart]
```

Now other services can connect to remote services using their service names:
- `payments:9001` instead of `localhost:9001`
- `grafana:3000` instead of `localhost:3000`
- etc.

## Files

- `Dockerfile` - Container images with required tools
- `run.sh` - Main script that creates SSH tunnels based on config.yml
- `config.yml` - Service configuration file (define your tunnels here)
- `config-template.yml` - Template for creating your config.yml
- `config.schema.json` - JSON schema for validating configuration
- `docker-compose.bifrost.yml` - Generated Docker Compose file for Bifrost service
- `docker-compose.heimdall.yml` - Heimdall (Bifrost generator) service configuration
- `docker-compose.template.yml` - Template for generating compose files
- `generate.sh` - Script to generate docker-compose.bifrost.yml from config
- `Makefile` - Make targets for Bifrost configuration and management
- `embeddable.mk` - Makefile that can be embedded in other projects

## Requirements

- Docker and Docker Compose
- SSH access to a remote host
- SSH private key for authentication
