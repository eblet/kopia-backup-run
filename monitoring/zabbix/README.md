# 🔍 Zabbix Integration for Kopia

## 📋 Overview
Enterprise-level monitoring integration for Kopia Backup System:
- 🔍 Active backup status checks
- 📊 Performance metrics collection
- 🚨 Customizable alerts
- 📱 Integration with Grafana

## 🏗️ Components

### 1. Monitoring Scripts

#### check_kopia_backup.sh
Validates backup status and integrity:
```bash
# Usage
/usr/lib/zabbix/externalscripts/check_kopia_backup.sh

# Returns JSON:
{
    "status": "ok|error",
    "latest_backup": "2024-01-20T02:00:00Z",
    "age_hours": 24,
    "validation": true,
    "size": 1024000,
    "files": 1000
}
```

#### check_nas_connection.sh
Monitors NAS connectivity:
```bash
# Usage
/usr/lib/zabbix/externalscripts/check_nas_connection.sh

# Return codes:
# 0 - OK
# 1 - NAS unreachable
# 2 - Share unavailable
# 3 - Mount issues
```

#### check_repository.sh
Verifies repository health:
```bash
# Usage
/usr/lib/zabbix/externalscripts/check_repository.sh

# Returns JSON:
{
    "status": "ok|error",
    "size": 1024000,
    "free_space": 10240000,
    "integrity": true
}
```

### 2. Templates

#### Backup Monitoring Template
- **Items:**
  - Backup Status (JSON)
  - Backup Age (hours)
  - Backup Size (bytes)
  - Files Count
  - Validation Status

- **Triggers:**
  ```yaml
  - name: "Backup too old"
    expression: {Kopia:kopia.backup.age.last()}>24
    severity: WARNING
    
  - name: "Backup validation failed"
    expression: {Kopia:kopia.backup.validation.last()}=0
    severity: HIGH
  ```

#### Repository Template
- **Items:**
  - Repository Size
  - Free Space
  - Growth Rate
  - Integrity Status

- **Triggers:**
  ```yaml
  - name: "Repository integrity check failed"
    expression: {Kopia:kopia.repo.integrity.last()}=0
    severity: HIGH
    
  - name: "Low repository space"
    expression: {Kopia:kopia.repo.free_space.last()}<10G
    severity: WARNING
  ```

### 3. User Parameters
```conf
# /etc/zabbix/zabbix_agentd.d/userparameter_kopia.conf

# Backup monitoring
UserParameter=kopia.backup.status,/usr/lib/zabbix/externalscripts/check_kopia_backup.sh
UserParameter=kopia.backup.age,/usr/lib/zabbix/externalscripts/check_kopia_backup.sh | jq .age_hours

# Repository monitoring
UserParameter=kopia.repo.status,/usr/lib/zabbix/externalscripts/check_repository.sh
UserParameter=kopia.repo.size,/usr/lib/zabbix/externalscripts/check_repository.sh | jq .size
```

## 🔧 Configuration

#### Profile-Specific Configuration

### Local Zabbix Profile
```bash
MONITORING_PROFILE=zabbix-local
# Additional settings:
ZABBIX_AGENT_HOSTNAME=${HOSTNAME}
ZABBIX_AGENT_PORT=10050
ZABBIX_AGENT_TIMEOUT=30
```

### External Zabbix Profile
```bash
MONITORING_PROFILE=zabbix-external
ZABBIX_ENABLED=true
ZABBIX_EXTERNAL=true
ZABBIX_URL=http://zabbix/api_jsonrpc.php
ZABBIX_SERVER_HOST=zabbix.local
```

### Agent Configuration
```conf
# Advanced agent settings
ServerActive=${ZABBIX_SERVER_HOST}
Hostname=${ZABBIX_AGENT_HOSTNAME}
Timeout=${ZABBIX_AGENT_TIMEOUT}
``` 

### Environment Variables
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| ZABBIX_URL | Zabbix API URL | http://zabbix-web:80/api_jsonrpc.php | http://zabbix.local/api_jsonrpc.php |
| ZABBIX_USERNAME | Admin username | Admin | zabbix_admin |
| ZABBIX_PASSWORD | Admin password | zabbix | secure-password |
| ZABBIX_EXTERNAL_SCRIPTS | Scripts directory | /usr/lib/zabbix/externalscripts | /opt/zabbix/scripts |
| ZABBIX_AGENT_CONFIG | Agent config directory | /etc/zabbix/zabbix_agentd.d | /etc/zabbix/conf.d |

### Integration with Grafana
```yaml
# Zabbix datasource configuration
datasources:
  - name: Zabbix
    type: alexanderzobnin-zabbix-datasource
    url: ${ZABBIX_URL}
    jsonData:
      username: ${ZABBIX_USERNAME}
      trendsFrom: "7d"
      trendsRange: "4d"
      cacheTTL: "1h"
    secureJsonData:
      password: ${ZABBIX_PASSWORD}
```

## 🛠 Troubleshooting

### Common Issues

1. Script Permissions
```bash
# Fix script permissions
chmod +x /usr/lib/zabbix/externalscripts/check_*.sh
chown zabbix:zabbix /usr/lib/zabbix/externalscripts/check_*.sh

# Verify permissions
ls -l /usr/lib/zabbix/externalscripts/check_*.sh
```

2. Agent Configuration
```bash
# Verify agent config
zabbix_agentd -t userparameter_kopia.conf

# Check syntax
zabbix_agentd -p | grep kopia

# Restart agent
systemctl restart zabbix-agent
```

3. Integration Issues
```bash
# Test API connection
curl -s -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"user.login","params":{"user":"${ZABBIX_USERNAME}","password":"${ZABBIX_PASSWORD}"},"id":1}' \
     ${ZABBIX_URL}

# Check agent logs
tail -f /var/log/zabbix/zabbix_agentd.log

# Test items manually
zabbix_agentd -t kopia.backup.status
```

### Debugging Tips
1. Enable debug logging in zabbix_agentd.conf:
```conf
DebugLevel=4
LogFile=/var/log/zabbix/zabbix_agentd.log
```

2. Test script outputs directly:
```bash
# Test backup check
sudo -u zabbix /usr/lib/zabbix/externalscripts/check_kopia_backup.sh

# Test NAS check
sudo -u zabbix /usr/lib/zabbix/externalscripts/check_nas_connection.sh
```

3. Verify Grafana integration:
```bash
# Check Zabbix plugin
docker exec kopia-grafana grafana-cli plugins ls | grep zabbix

# Test datasource
curl -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
     http://localhost:3000/api/datasources/proxy/1/api/v1/items
```

## 📚 Additional Resources
- [Zabbix Documentation](https://www.zabbix.com/documentation/)
- [Grafana-Zabbix Plugin](https://grafana.com/grafana/plugins/alexanderzobnin-zabbix-datasource/)
- [Template Reference](https://www.zabbix.com/documentation/current/manual/config/templates)
- [Zabbix API Documentation](https://www.zabbix.com/documentation/current/manual/api) 

