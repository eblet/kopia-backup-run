# 📊 Chapter 3: Monitoring

## Table of Contents
- [Overview](#overview)
- [Monitoring Profiles](#monitoring-profiles)
- [Components](#components)
- [Metrics & Alerts](#metrics--alerts)
- [Dashboards](#dashboards)
- [Configuration](#configuration)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## Overview

The monitoring system provides comprehensive visibility into:
- 🔄 Backup operations status
- 💾 Repository health
- 📈 Performance metrics
- 🚨 Real-time alerts
- 🖥️ System resources

## Monitoring Profiles

### Profile Comparison

| Feature | none | base-metrics | grafana-local | grafana-external | zabbix-external | prometheus-external | grafana-zabbix-external | all-external | full-stack |
|---------|------|--------------|---------------|------------------|-----------------|-------------------|----------------------|--------------|------------|
| Kopia Exporter | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Node Exporter | ❌ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Zabbix Agent | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ |
| Local Prometheus | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Local Grafana | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Local Zabbix | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| External Grafana | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| External Zabbix | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ✅ | ❌ |
| External Prometheus | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |

### Profile Configuration

1. **No Monitoring** (`none`)
```bash
MONITORING_PROFILE=none

# Effect:
# - All monitoring components disabled
# - No metrics collection
# - Minimal resource usage
```

2. **Base Metrics** (`base-metrics`)
```bash
MONITORING_PROFILE=base-metrics

# Required Settings
PROMETHEUS_RETENTION_TIME=15d
PROMETHEUS_RETENTION_SIZE=10GB
PROMETHEUS_SCRAPE_INTERVAL=15s

# Optional Settings
PROMETHEUS_WAL_RETENTION=12h
PROMETHEUS_QUERY_TIMEOUT=2m
```

3. **Local Grafana** (`grafana-local`)
```bash
MONITORING_PROFILE=grafana-local

# Required Settings
GRAFANA_ADMIN_PASSWORD=secure-password
GRAFANA_DOMAIN=localhost

# Optional Settings
GRAFANA_INSTALL_PLUGINS=alexanderzobnin-zabbix-datasource,grafana-clock-panel
GRAFANA_SMTP_ENABLED=true
GRAFANA_SMTP_HOST=smtp.company.com
GRAFANA_ALLOW_SIGN_UP=false
```

4. **External Grafana** (`grafana-external`)
```bash
MONITORING_PROFILE=grafana-external

# Required Settings
GRAFANA_URL=http://grafana:3000
GRAFANA_API_KEY=your-api-key

# Optional Settings
GRAFANA_ORG_ID=1
GRAFANA_VERIFY_SSL=true
GRAFANA_TIMEOUT=30s
```

5. **External Zabbix** (`zabbix-external`)
```bash
MONITORING_PROFILE=zabbix-external

# Required Settings
ZABBIX_SERVER=zabbix.company.com
ZABBIX_SERVER_PORT=10051
ZABBIX_HOSTNAME=kopia-backup-host

# Optional Settings
ZABBIX_TLS_ENABLED=true
ZABBIX_TLS_PSK_IDENTITY=PSK_ID
ZABBIX_TLS_PSK_FILE=/etc/zabbix/psk.key
```

6. **External Prometheus** (`prometheus-external`)
```bash
MONITORING_PROFILE=prometheus-external

# Required Settings
PROMETHEUS_URL=http://prometheus:9090
PROMETHEUS_BASIC_AUTH=true
PROMETHEUS_AUTH_USER=user
PROMETHEUS_AUTH_PASSWORD=pass

# Optional Settings
PROMETHEUS_EXTERNAL_LABELS="environment=prod,datacenter=eu-west"
PROMETHEUS_REMOTE_TIMEOUT=30s
```

7. **External Grafana + Zabbix** (`grafana-zabbix-external`)
```bash
MONITORING_PROFILE=grafana-zabbix-external

# Grafana Settings
GRAFANA_URL=http://grafana:3000
GRAFANA_API_KEY=your-api-key

# Zabbix Settings
ZABBIX_SERVER=zabbix.company.com
ZABBIX_SERVER_PORT=10051

# Integration Settings
GRAFANA_ZABBIX_USERNAME=api_user
GRAFANA_ZABBIX_PASSWORD=api_pass
GRAFANA_ZABBIX_TRENDS_FROM=7d
```

8. **All External** (`all-external`)
```bash
MONITORING_PROFILE=all-external

# Grafana Settings
GRAFANA_URL=http://grafana:3000
GRAFANA_API_KEY=your-api-key

# Zabbix Settings
ZABBIX_SERVER=zabbix.company.com
ZABBIX_SERVER_PORT=10051

# Prometheus Settings
PROMETHEUS_URL=http://prometheus:9090
PROMETHEUS_BASIC_AUTH=true

# Integration Settings
GRAFANA_DEFAULT_DATASOURCE=Prometheus
ZABBIX_EXPORT_METRICS=true
```

9. **Full Stack** (`full-stack`)
```bash
MONITORING_PROFILE=full-stack

# Resource Limits
PROMETHEUS_CPU_LIMIT=2
PROMETHEUS_MEM_LIMIT=2G
GRAFANA_CPU_LIMIT=1
GRAFANA_MEM_LIMIT=1G
ZABBIX_CPU_LIMIT=1
ZABBIX_MEM_LIMIT=1G

# Storage Settings
PROMETHEUS_RETENTION_TIME=30d
PROMETHEUS_RETENTION_SIZE=50GB
GRAFANA_PROVISIONING_PATH=/etc/grafana/provisioning

# Security Settings
MONITORING_BASIC_AUTH=true
MONITORING_AUTH_USER=admin
MONITORING_AUTH_PASSWORD=secure-password

# Integration Settings
GRAFANA_INSTALL_PLUGINS=alexanderzobnin-zabbix-datasource,grafana-clock-panel
ZABBIX_START_POLLERS=5
ZABBIX_CACHE_SIZE=8M
```

### Resource Requirements

| Profile | CPU | Memory | Disk | Network |
|---------|-----|--------|------|---------|
| none | - | - | - | - |
| base-metrics | 0.5 | 512MB | 5GB | Low |
| grafana-local | 1.0 | 1GB | 10GB | Medium |
| grafana-external | 0.5 | 512MB | 5GB | Medium |
| zabbix-external | 0.2 | 256MB | 1GB | Low |
| prometheus-external | 0.5 | 512MB | 1GB | Medium |
| grafana-zabbix-external | 0.5 | 512MB | 1GB | Medium |
| all-external | 0.5 | 512MB | 1GB | High |
| full-stack | 2.0 | 2GB | 20GB | High |

### Profile Selection Guide

Choose your profile based on:

1. **Infrastructure**
   - Existing monitoring systems
   - Available resources
   - Network topology

2. **Requirements**
   - Visualization needs
   - Alert complexity
   - Data retention

3. **Integration**
   - External systems
   - Authentication methods
   - Data sources

4. **Resources**
   - Available CPU/Memory
   - Storage capacity
   - Network bandwidth

## Components

### Core Components

1. **Kopia Exporter**
```yaml
# docker-compose.yml
kopia-exporter:
  build: ./monitoring/exporters/kopia-exporter
  ports:
    - "9091:9091"
  environment:
    - KOPIA_SERVER=kopia-server:51515
    - COLLECTION_INTERVAL=15s
```

2. **Node Exporter**
```yaml
node-exporter:
  image: prom/node-exporter
  ports:
    - "9100:9100"
  volumes:
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
```

3. **Prometheus**
```yaml
prometheus:
  image: prom/prometheus
  ports:
    - "9090:9090"
  volumes:
    - ./prometheus/:/etc/prometheus/
    - prometheus_data:/prometheus
```

4. **Grafana**
```yaml
grafana:
  image: grafana/grafana
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
```

## Metrics & Alerts

### Key Metrics

1. **Backup Metrics**
```promql
# Backup Status
kopia_backup_status{source="path"}

# Backup Size
rate(kopia_backup_size_bytes[5m])

# Backup Duration
kopia_backup_duration_seconds
```

2. **Repository Metrics**
```promql
# Repository Status
kopia_repository_status

# Repository Size
kopia_repository_size_bytes

# Free Space
kopia_repository_free_space_bytes
```

### Alert Rules

1. **Backup Failures**
```yaml
- alert: KopiaBackupFailed
  expr: kopia_backup_status == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Backup failed for {{ $labels.source }}"
```

2. **Repository Space**
```yaml
- alert: KopiaRepositoryLowSpace
  expr: kopia_repository_free_space_bytes < 10737418240  # 10GB
  for: 15m
  labels:
    severity: warning
```

## Dashboards

### Overview Dashboard
```json
{
  "dashboard": {
    "title": "Kopia Overview",
    "panels": [
      {
        "title": "Backup Status",
        "type": "stat",
        "targets": [
          {
            "expr": "kopia_backup_status"
          }
        ]
      }
    ]
  }
}
```

### Performance Dashboard
```json
{
  "dashboard": {
    "title": "Kopia Performance",
    "panels": [
      {
        "title": "Backup Duration",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(kopia_backup_duration_seconds[5m])"
          }
        ]
      }
    ]
  }
}
```

## Configuration

### Prometheus Configuration
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'kopia'
    static_configs:
      - targets: ['kopia-exporter:9091']
```

### Grafana Configuration
```ini
# grafana.ini
[security]
admin_user = admin
admin_password = ${GRAFANA_ADMIN_PASSWORD}

[dashboards]
default_home_dashboard_path = /etc/grafana/dashboards/kopia_overview.json
```

## Maintenance

### Daily Tasks
```bash
# Check metrics collection
curl -s http://localhost:9091/metrics | grep kopia

# Verify alerts
curl -s http://localhost:9090/api/v1/alerts
```

### Weekly Tasks
```bash
# Backup dashboards
./scripts/backup_dashboards.sh

# Check storage usage
docker exec prometheus prometheus tsdb analyze
```

## Troubleshooting

### Common Issues

1. **Missing Metrics**
```bash
# Check exporter
docker logs kopia-exporter
curl -s http://localhost:9091/metrics
```

2. **Alert Issues**
```bash
# Verify rules
docker exec prometheus promtool check rules /etc/prometheus/rules/*.yml

# Check alert manager
curl -s http://localhost:9093/-/healthy
```

### Performance Optimization
```yaml
# prometheus.yml
storage:
  tsdb:
    retention.time: 15d
    retention.size: 10GB
    wal:
      retention.period: "12h"
```

[Continue to Chapter 4: Security →](chapter4_security.md) 