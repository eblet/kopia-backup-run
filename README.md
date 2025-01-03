# 🚀 Kopia Backup System + Monitoring Stack

## 📋 Overview
Modular backup solution with optional monitoring:
- 🔄 Core: Kopia Server & Client
- 📊 Optional: Monitoring Stack
- 🔐 Secure and scalable
- 🚀 Easy deployment

## 🏗️ Architecture

```mermaid
graph TB
    subgraph "Backup Infrastructure"
        subgraph "Client Layer"
            C1[Kopia Client 1]
            C2[Kopia Client 2]
            C3[Kopia Client N]
        end

        subgraph "Server Layer"
            KS[Kopia Server]
            R[(Repository)]
            N[(NAS Storage)]
        end

        subgraph "Monitoring Layer"
            M[Monitoring Stack]
        end
    end

    C1 & C2 & C3 -->|Backup| KS
    KS -->|Store| R
    R -->|Sync| N
    KS -->|Metrics| M

    style KS fill:#f9f,stroke:#333
    style M fill:#bbf,stroke:#333
    style R fill:#bfb,stroke:#333
```

## 🚀 Quick Start

### 1. Server Setup (Required)

#### Prerequisites
```bash
# Server Requirements
- Docker Engine 20.10+
- Docker Compose 2.0+
- 2GB RAM minimum
- 10GB disk space
- NFS server access
```

#### Server Installation
```bash
# Clone repository
git clone https://github.com/eblet/kopia-backup-stack
cd kopia-backup-stack

# Configure server settings
cp .env.example .env
nano .env

# Required Server Variables
KOPIA_REPO_PASSWORD=strong-password-here      # Min 16 chars
KOPIA_SERVER_USERNAME=admin                   # Min 8 chars
KOPIA_SERVER_PASSWORD=another-strong-password # Min 16 chars
KOPIA_SERVER_IP=192.168.1.100                # Server IP

# NAS Configuration
NAS_IP=192.168.1.200
NAS_SHARE=/backup
NAS_MOUNT_PATH=/mnt/nas

# Deploy server
sudo ./scripts/setup_server.sh
or
docker-compose -f docker/docker-compose.server.yml up -d
```

#### Verify Server
```bash
# Check server status
systemctl status kopia-server

# Check logs
journalctl -u kopia-server

# Test repository
docker exec kopia-server kopia repository status
```

### 2. Client Setup

#### Prerequisites
```bash
# Client Requirements
- Docker Engine 20.10+
- Docker Compose 2.0+
- 1GB RAM minimum
- Access to Kopia server
```

#### Client Configuration
```bash
# Clone repository on client machine
git clone https://github.com/eblet/kopia-backup-stack
cd kopia-backup-stack

# Configure client settings
cp .env.example .env
nano .env

# Required Client Variables
KOPIA_REPO_PASSWORD=same-as-server-password
KOPIA_SERVER_USERNAME=admin
KOPIA_SERVER_PASSWORD=server-password
KOPIA_SERVER_IP=192.168.1.100    # Server IP

# Configure backup paths
DOCKER_VOLUMES='{
    "/path/to/config": {
        "name": "app-config",
        "tags": ["type:config"],
        "compression": "zstd-max",
        "priority": 2
    }
    "/path/to/data2": {
        "name": "app-data2",
        "tags": ["type:data2", "app:myapp2"],
        "compression": "zstd-fastest",
        "priority": 1
    },
}'
```

#### Run Client Backup
```bash
# Manual backup
cd /path/to/kopia-backup-stack
# Using script (recommended)
sudo ./scripts/setup_client.sh
# OR using docker-compose directly
docker-compose -f docker/docker-compose.client.yml up -d

# Setup scheduled backup (optional)
sudo crontab -e

# Add schedule (example: daily at 2 AM)
# Using script (recommended):
0 2 * * * cd /path/to/kopia-backup-stack && ./scripts/kopia_client_docker_run.sh

# OR using docker-compose:
0 2 * * * cd /path/to/kopia-backup-stack && docker-compose -f docker/docker-compose.client.yml up -d
```

#### Verify Backup
```bash
# Check backup status and logs
docker logs kopia-client

# List snapshots
docker exec kopia-client kopia snapshot list

# Verify specific snapshot
docker exec kopia-client kopia snapshot verify latest
```

### 3. Monitoring Setup (Optional)

#### Deploy Monitoring Stack

If you want to add monitoring later:

```bash
# Edit .env
nano .env

# Deploy monitoring stack
sudo ./scripts/setup_monitoring.sh
or
docker-compose -f monitoring/docker-compose.monitoring.yml up -d

# Access dashboards
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
```

## 🔧 Monitoring Options

### 1. Basic Monitoring
```bash
# Server status
docker logs kopia-server
docker exec kopia-server kopia repository status
```

### 2. Enterprise Monitoring
Enable full monitoring stack:
```bash
# Edit .env
MONITORING_TYPE=all  # all, zabbix, prometheus, none

# Deploy
./scripts/setup_monitoring.sh
```

### 3. Available Metrics
- 📈 Backup size and duration
- 💾 Repository status
- 🔄 Sync status
- 📊 System resources

## 🛠 Troubleshooting

### Common Issues

1. Connection Problems
```bash
# Check Docker networks
docker network ls
docker network inspect kopia_network

# Verify services
docker ps | grep kopia
```

2. Permission Issues
```bash
# Fix permissions
sudo chown -R 65534:65534 /var/lib/prometheus
sudo chown -R 472:472 /var/lib/grafana
```

3. Monitoring Issues
```bash
# Check logs
docker logs kopia-prometheus
docker logs kopia-grafana
docker logs kopia-exporter
```

## 📚 Configuration Reference

### Server Configuration
| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| KOPIA_REPO_PASSWORD | Repository encryption | ✅ | - |
| KOPIA_SERVER_USERNAME | Admin username | ✅ | - |
| KOPIA_SERVER_PASSWORD | Admin password | ✅ | - |
| KOPIA_SERVER_IP | Server address | ✅ | - |
| NAS_IP | NAS server address | ✅ | - |
| NAS_SHARE | NFS share path | ✅ | - |
| KOPIA_SECURE_MODE | Enable TLS | ❌ | false |

### Client Configuration
| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| KOPIA_REPO_PASSWORD | Same as server | ✅ | - |
| KOPIA_SERVER_USERNAME | Server username | ✅ | - |
| KOPIA_SERVER_PASSWORD | Server password | ✅ | - |
| KOPIA_SERVER_IP | Server address | ✅ | - |
| DOCKER_VOLUMES | Backup paths | ✅ | - |
| BACKUP_VERIFY | Verify after backup | ❌ | true |

## 📚 Documentation
- [Monitoring Guide](monitoring/README.md)

## 🤝 Contributing
1. Fork repository
2. Create feature branch
3. Commit changes
4. Create pull request

## 📄 License
MIT License - see LICENSE file