# 🔧 Chapter 5: Maintenance

## Table of Contents
- [Overview](#overview)
- [Routine Tasks](#routine-tasks)
- [Backup Management](#backup-management)
- [System Updates](#system-updates)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting](#troubleshooting)
- [Disaster Recovery](#disaster-recovery)

## Overview

Maintenance procedures ensure:
- 🔄 System reliability
- 📈 Optimal performance
- 🛡️ Security compliance
- 💾 Data integrity
- 🚨 Problem prevention

## Routine Tasks

### Daily Checks

1. **Backup Status**
```bash
# Check recent backups
docker exec kopia-server kopia snapshot list --last 24h

# Verify backup completion
docker exec kopia-server kopia snapshot verify \
    --verify-files-percent=5 \
    --parallel=4

# Check repository status
docker exec kopia-server kopia repository status
```

2. **Monitoring Health**
```bash
# Check monitoring stack
docker compose ps

# Verify metrics collection
curl -s http://localhost:9091/metrics | grep kopia
curl -s http://localhost:9090/-/healthy

# Check alerts
curl -s http://localhost:9090/api/v1/alerts
```

3. **System Resources**
```bash
# Check disk space
df -h /var/lib/kopia /repository

# Monitor resource usage
docker stats kopia-server prometheus grafana

# Check logs
docker compose logs --tail=100
```

### Weekly Tasks

1. **Repository Maintenance**
```bash
# Run maintenance
docker exec kopia-server kopia maintenance run

# Verify indexes
docker exec kopia-server kopia index verify

# Check content integrity
docker exec kopia-server kopia content verify \
    --parallel=4 \
    --verify-files-percent=10
```

2. **Performance Analysis**
```bash
# Analyze backup times
docker exec kopia-server kopia snapshot stats

# Check compression ratios
docker exec kopia-server kopia content stats

# Monitor resource trends
./scripts/analyze_performance.sh
```

3. **Security Checks**
```bash
# Review access logs
grep -i error /var/log/kopia/*.log

# Check authentication attempts
docker exec kopia-server kopia audit-log list --last 7d

# Verify SSL certificates
./scripts/check_certificates.sh
```

### Monthly Tasks

1. **Full System Audit**
```bash
# Complete repository check
docker exec kopia-server kopia repository validate-full

# Verify all snapshots
docker exec kopia-server kopia snapshot verify \
    --verify-files-percent=100 \
    --parallel=4

# Test recovery procedures
./scripts/test_recovery.sh
```

2. **Configuration Backup**
```bash
# Backup configurations
./scripts/backup_configs.sh

# Export Grafana dashboards
./scripts/backup_dashboards.sh

# Archive logs
./scripts/archive_logs.sh
```

3. **System Updates**
```bash
# Update containers
docker compose pull
docker compose up -d

# Update system packages
apt-get update && apt-get upgrade -y

# Rebuild custom images
docker compose build --no-cache
```

## Backup Management

### Policy Maintenance
```bash
# Review global policy
docker exec kopia-server kopia policy show --global

# Update retention
docker exec kopia-server kopia policy set --global \
    --keep-latest=30 \
    --keep-hourly=24 \
    --keep-daily=7 \
    --keep-weekly=4 \
    --keep-monthly=6

# Check policy compliance
docker exec kopia-server kopia policy verify
```

### Storage Optimization
```bash
# Analyze space usage
docker exec kopia-server kopia content stats

# Remove old snapshots
docker exec kopia-server kopia snapshot delete \
    --older-than=180d \
    --delete-unmatched

# Compact repository
docker exec kopia-server kopia maintenance run --full
```

## System Updates

### Component Updates
```bash
# Update procedure
./scripts/update_system.sh

# Version check
docker exec kopia-server kopia --version
docker compose version

# Verify compatibility
./scripts/verify_versions.sh
```

### Configuration Updates
```bash
# Apply new configs
./scripts/update_configs.sh

# Reload services
docker compose restart

# Verify changes
./scripts/verify_config.sh
```

## Performance Optimization

### Resource Tuning
```yaml
# docker-compose.yml
services:
  kopia-server:
    environment:
      - KOPIA_CACHE_SIZE=5G
      - KOPIA_PARALLEL_UPLOADS=4
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

### Monitoring Optimization
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

storage:
  tsdb:
    retention.time: 15d
    retention.size: 10GB
    wal:
      retention.period: "12h"
```

## Troubleshooting

### Common Issues

1. **Backup Failures**
```bash
# Check logs
docker logs kopia-server

# Verify connectivity
docker exec kopia-server kopia repository status

# Test backup
docker exec kopia-server kopia snapshot create --path=/test
```

2. **Performance Issues**
```bash
# Check resource usage
docker stats

# Analyze metrics
curl -s http://localhost:9090/api/v1/query?query=rate(kopia_backup_duration_seconds[5m])

# Review logs
grep -i slow /var/log/kopia/*.log
```

## Disaster Recovery

### Backup Recovery
```bash
# Repository recovery
docker exec kopia-server kopia repository repair

# Snapshot restore
docker exec kopia-server kopia snapshot restore \
    --snapshot-id=latest \
    --target=/recovery

# Verify restoration
docker exec kopia-server kopia snapshot verify \
    --snapshot-id=latest
```

### System Recovery
```bash
# Configuration restore
./scripts/restore_configs.sh

# Service recovery
docker compose down
docker compose up -d

# Verify system
./scripts/verify_system.sh
```

### Documentation
- Keep maintenance logs
- Update procedures
- Record incidents
- Document solutions
- Update runbooks