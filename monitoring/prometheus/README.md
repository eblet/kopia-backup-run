# 📊 Prometheus Stack for Kopia

## 📋 Overview
Real-time metrics collection and visualization for Kopia Backup System:
- 🔍 Custom metrics exporter for Kopia
- 📈 Pre-configured Grafana dashboards
- 🚨 Intelligent alert rules
- 📊 System resource monitoring

## 🏗️ Components

### 1. Kopia Exporter

#### Overview
Custom Python-based exporter that collects Kopia-specific metrics:
```python
# Example metric collection
def collect_backup_metrics():
    return {
        'kopia_backup_duration_seconds': duration,
        'kopia_backup_size_bytes': size,
        'kopia_snapshot_count': count
    }
```

#### Available Endpoints
```bash
# Metrics endpoint
curl http://localhost:9091/metrics

# Health check
curl http://localhost:9091/-/healthy

# Ready check
curl http://localhost:9091/-/ready
```

### 2. Node Exporter

#### System Metrics
- **CPU Usage:**
  ```promql
  rate(node_cpu_seconds_total{mode="user"}[5m])
  ```
- **Memory Usage:**
  ```promql
  node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes
  ```
- **Disk Usage:**
  ```promql
  node_filesystem_free_bytes
  ```
- **Network Stats:**
  ```promql
  rate(node_network_transmit_bytes_total[5m])
  ```

### 3. Prometheus Configuration

#### Main Config
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'kopia'
    static_configs:
      - targets: ['kopia-exporter:9091']
    metrics_path: '/metrics'
    scheme: 'http'

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
```

#### Alert Rules
```yaml
# rules/kopia_alerts.yml
groups:
  - name: kopia_alerts
    rules:
      - alert: KopiaBackupFailed
        expr: kopia_backup_status == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Backup operation failed"
```

### 4. Grafana Dashboards

#### Backup Overview Dashboard
- **Panels:**
  - Backup Success Rate
  - Backup Duration Trend
  - Repository Size Growth
  - Latest Backup Status

#### System Resources Dashboard
- **Panels:**
  - CPU Usage
  - Memory Consumption
  - Disk Space
  - Network Traffic

## 🔧 Configuration

### Base Metrics Profile
```yaml
# Minimal prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'kopia'
    static_configs:
      - targets: ['kopia-exporter:9091']
```

### With Authentication (Optional)
```yaml
# Enable basic auth
PROMETHEUS_BASIC_AUTH=true
PROMETHEUS_AUTH_USER=admin
PROMETHEUS_AUTH_PASSWORD=secure-password
```

### External Access
```yaml
# Configure CORS for external Grafana
command:
  - '--web.enable-cors=true'
  - '--web.cors.origin=*'
```

### Environment Variables

#### Prometheus Settings
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| PROMETHEUS_UI_PORT | Web interface port | 9090 | 9090 |
| PROMETHEUS_DATA_DIR | Data directory | /var/lib/prometheus | /data/prometheus |
| PROMETHEUS_RETENTION | Data retention | 15d | 30d |
| PROMETHEUS_CPU_LIMIT | CPU limit | 1 | 2 |
| PROMETHEUS_MEM_LIMIT | Memory limit | 2G | 4G |

#### Grafana Settings
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| GRAFANA_PORT | Web interface port | 3000 | 3000 |
| GRAFANA_ADMIN_PASSWORD | Admin password | admin | secure-password |
| GRAFANA_PLUGINS | Additional plugins | - | grafana-piechart-panel |

### Data Source Configuration
```yaml
# datasources/prometheus.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

## 📊 Available Metrics

### Kopia Metrics
| Metric | Type | Description | Labels |
|--------|------|-------------|--------|
| kopia_backup_duration_seconds | Gauge | Backup duration | path, status |
| kopia_backup_size_bytes | Gauge | Total backup size | path |
| kopia_snapshot_count | Gauge | Number of snapshots | type |
| kopia_repository_size_bytes | Gauge | Repository size | - |

### System Metrics
| Metric | Type | Description | Labels |
|--------|------|-------------|--------|
| node_cpu_seconds_total | Counter | CPU time | cpu, mode |
| node_memory_MemAvailable_bytes | Gauge | Available memory | - |
| node_filesystem_free_bytes | Gauge | Free disk space | device, mountpoint |

## 🛠 Troubleshooting

### Common Issues

1. Metrics Collection
```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq .

# Test Kopia exporter
curl -s http://localhost:9091/metrics

# Verify scrape config
docker exec kopia-prometheus promtool check config /etc/prometheus/prometheus.yml
```

2. Storage Issues
```bash
# Check disk usage
du -sh ${PROMETHEUS_DATA_DIR}

# Verify permissions
ls -l ${PROMETHEUS_DATA_DIR}

# Clean old data
docker exec kopia-prometheus prometheus clean tombstones
```

3. Query Problems
```bash
# Test PromQL query
curl -G --data-urlencode 'query=up' http://localhost:9090/api/v1/query

# Check query performance
curl http://localhost:9090/api/v1/query_stats
```

### Debugging Tips

1. Enable Debug Logging
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  log_level: debug
```

2. Check Metrics Directly
```bash
# Raw metrics
curl -s http://localhost:9091/metrics | grep kopia_

# Processed metrics
curl -s http://localhost:9090/api/v1/query?query=kopia_backup_status
```

3. Validate Configuration
```bash
# Check Prometheus config
docker exec kopia-prometheus promtool check config /etc/prometheus/prometheus.yml

# Test alert rules
docker exec kopia-prometheus promtool check rules /etc/prometheus/rules/*.yml
```

## 🔒 Security

### Network Security
- Isolated monitoring network
- Internal service discovery
- No external access to exporters
- TLS encryption (optional)

### Access Control
- Basic authentication
- Role-based access in Grafana
- Read-only access to metrics
- Secure API endpoints

## 📚 Additional Resources
- [Prometheus Documentation](https://prometheus.io/docs/)
- [PromQL Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Node Exporter](https://github.com/prometheus/node_exporter)
