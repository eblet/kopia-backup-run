# 🚀 Kopia Backup Stack

## Overview
Enterprise-grade backup solution using Kopia with comprehensive monitoring capabilities.

## Documentation Structure

### 📋 Chapter 1: Introduction
Detailed introduction to the Kopia Backup Stack system is available in [docs/chapter1_introduction.md](docs/chapter1_introduction.md):
- System overview and architecture
- Core components and features
- Quick start guide
- Basic concepts

### 🛠️ Chapter 2: Installation
Complete installation instructions can be found in [docs/chapter2_installation.md](docs/chapter2_installation.md):
- System requirements
- Server installation
- Client setup
- Configuration options
- Post-installation steps

### 📊 Chapter 3: Monitoring
Comprehensive monitoring guide is available in [docs/chapter3_monitoring.md](docs/chapter3_monitoring.md):
- Monitoring profiles and comparison
- Component setup (Prometheus, Grafana, Zabbix)
- Metrics and alerts configuration
- Dashboard setup
- Performance monitoring

### 🔐 Chapter 4: Security
Security documentation is detailed in [docs/chapter4_security.md](docs/chapter4_security.md):
- Authentication and authorization
- TLS/SSL configuration
- Network security
- Access control
- Security best practices

### 🔧 Chapter 5: Maintenance
System maintenance procedures are described in [docs/chapter5_maintenance.md](docs/chapter5_maintenance.md):
- Routine tasks
- Backup management
- System updates
- Performance optimization
- Troubleshooting

## Quick Start

### Server Setup
```bash
# Clone repository
git clone https://github.com/eblet/kopia-backup-stack
cd kopia-backup-stack

# Configure environment
cp .env.example .env
nano .env

# Initialize server
./scripts/setup_server.sh
```

### Client Setup
```bash
# Setup client
./scripts/setup_client.sh

# Configure backup paths
docker exec kopia-client kopia policy set /data \
    --compression=zstd \
    --snapshot-time-schedule="0 2 * * *"
```

### Monitoring Setup
```bash
# Initialize monitoring
./scripts/setup_monitoring.sh

# Access dashboards
# Grafana: http://localhost:3000
# Prometheus: http://localhost:9090
# Zabbix: http://localhost/zabbix
```

## Configuration Files

### Core Configuration
- `.env.example` - Environment variables template
- `docker/docker-compose.server.yml` - Server container configuration
- `docker/docker-compose.client.yml` - Client container configuration

### Monitoring Configuration
- `monitoring/prometheus/config/` - Prometheus configuration
- `monitoring/zabbix/templates/` - Zabbix templates
- `monitoring/exporters/` - Custom exporters

### Web Server Configuration
- `docs/conf/nginx.conf` - Nginx configuration example
- `docs/conf/traefik.yml` - Traefik configuration example

## Directory Structure
```bash
.
├── docs/                  # Documentation
│   ├── chapter1_introduction.md
│   ├── chapter2_installation.md
│   ├── chapter3_monitoring.md
│   ├── chapter4_security.md
│   ├── chapter5_maintenance.md
│   └── conf/             # Configuration examples
├── docker/               # Docker compositions
├── monitoring/           # Monitoring components
│   ├── exporters/       # Custom exporters
│   ├── prometheus/      # Prometheus configuration
│   └── zabbix/          # Zabbix templates
└── scripts/             # Setup and maintenance scripts
```

## Additional Resources

### Documentation
- [Kopia Documentation](https://kopia.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Zabbix Documentation](https://www.zabbix.com/documentation/)

### Related Projects
- [Kopia](https://github.com/kopia/kopia)
- [Prometheus](https://github.com/prometheus/prometheus)
- [Grafana](https://github.com/grafana/grafana)
- [Zabbix](https://github.com/zabbix/zabbix)

### License
MIT License - see [LICENSE](LICENSE) for details.
