# 🛠️ Chapter 2: Installation

## Table of Contents
- [System Requirements](#system-requirements)
- [Installation Methods](#installation-methods)
- [Basic Installation](#basic-installation)
- [Advanced Installation](#advanced-installation)
- [Component Setup](#component-setup)
- [Post-Installation](#post-installation)

## System Requirements

### Hardware Requirements
```bash
# Minimum Requirements
CPU: 2 cores
RAM: 2GB
Disk: 10GB

# Recommended Requirements
CPU: 4 cores
RAM: 4GB
Disk: 20GB + backup storage
```

### Software Requirements
```bash
# Required Packages
- Docker 20.10+
- Docker Compose 2.0+
- NFS client
- curl
- jq

# Optional Packages
- OpenSSL (for TLS)
- Python 3.8+ (for scripts)
- Git (for installation)
```

### Network Requirements
```bash
# Required Ports
51515 - Kopia Server
9090  - Prometheus
9091  - Kopia Exporter
9100  - Node Exporter
3000  - Grafana
10050 - Zabbix Agent
10051 - Zabbix Server
```

## Installation Methods

### Standard Installation
- Basic setup with default settings
- Local monitoring stack
- Suitable for most deployments

### Enterprise Installation
- High-availability setup
- External monitoring integration
- Advanced security features

### Development Setup
- Full local stack
- Debug capabilities
- Testing environment

## Basic Installation

### 1. Prepare Environment
```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install dependencies
sudo apt-get install -y \
    docker.io \
    docker-compose \
    nfs-common \
    curl \
    jq

# Add user to docker group
sudo usermod -aG docker $USER
```

### 2. Get Source Code
```bash
# Clone repository
git clone https://github.com/eblet/kopia-backup-stack
cd kopia-backup-stack

# Configure environment
cp .env.example .env
```

### 3. Configure Environment
```bash
# Basic Configuration
KOPIA_SERVER_IP=0.0.0.0
KOPIA_SERVER_PORT=51515
KOPIA_REPO_PATH=/repository

# Security Settings
KOPIA_SERVER_USERNAME=admin
KOPIA_SERVER_PASSWORD=secure-password
KOPIA_REPO_PASSWORD=repo-password

# Monitoring Profile
MONITORING_PROFILE=grafana-local
```

### 4. Start Services
```bash
# Initialize server
./scripts/setup_server.sh

# Verify installation
docker compose ps
curl -s http://localhost:51515/api/v1/repo/status
```

## Advanced Installation

### High-Availability Setup
```bash
# Enable HA mode
HA_MODE=true
HA_NODES=3
CLUSTER_NAME=kopia-cluster

# Start HA cluster
./scripts/setup_ha.sh
```

### External Services Integration
```bash
# Grafana integration
GRAFANA_EXTERNAL=true
GRAFANA_URL=http://grafana.company.com
GRAFANA_API_KEY=your-api-key

# Zabbix integration
ZABBIX_EXTERNAL=true
ZABBIX_SERVER=zabbix.company.com
ZABBIX_SERVER_PORT=10051
```

### Custom SSL Configuration
```bash
# If you want to enable TLS
KOPIA_SECURE_MODE=true
KOPIA_TLS_CERT_PATH=/path/to/cert.pem
KOPIA_TLS_KEY_PATH=/path/to/key.pem
```

## Component Setup

### 1. Server Setup
```bash
# Initialize repository
docker exec kopia-server kopia repository create filesystem \
    --path=/repository \
    --password=${KOPIA_REPO_PASSWORD}

# Configure server
docker exec kopia-server kopia server start \
    --address=0.0.0.0:51515 \
    --server-username=${KOPIA_SERVER_USERNAME} \
    --server-password=${KOPIA_SERVER_PASSWORD}
```

### 2. Client Setup
```bash
# Connect client
./scripts/setup_client.sh

# Configure backup paths
docker exec kopia-client kopia policy set /data \
    --compression=zstd \
    --snapshot-time-schedule="0 2 * * *"
```

### 3. Monitoring Setup
```bash
# Initialize monitoring
./scripts/setup_monitoring.sh

# Verify components
curl -s http://localhost:9090/-/healthy  # Prometheus
curl -s http://localhost:3000/api/health # Grafana
```

## Post-Installation

### Verification Checklist
- [ ] Server is running
- [ ] Repository is initialized
- [ ] Client can connect
- [ ] Monitoring is active
- [ ] Backups are scheduled
- [ ] Alerts are configured

### Security Checklist
- [ ] TLS enabled
- [ ] Strong passwords set
- [ ] Firewall configured
- [ ] Network isolated
- [ ] Monitoring secured

### Initial Configuration
```bash
# Set global policy
docker exec kopia-server kopia policy set --global \
    --compression=zstd \
    --keep-latest=30 \
    --keep-hourly=24 \
    --keep-daily=7

# Configure retention
docker exec kopia-server kopia policy set --global \
    --keep-weekly=4 \
    --keep-monthly=6
```

### Next Steps
1. Configure backup policies
2. Set up monitoring alerts
3. Create backup schedules
4. Test recovery procedures
5. Document configuration

[Continue to Chapter 3: Monitoring →](chapter3_monitoring.md) 