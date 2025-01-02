# 🔍 Kopia Backup Zabbix Monitoring

## Overview

Zabbix monitoring solution for Kopia Backup System includes:
- Backup status monitoring
- NAS connectivity checks
- Repository validation
- Client connectivity monitoring

## Requirements

- Zabbix Server 6.0+
- Zabbix Agent 6.0+
- jq package
- curl package

## Installation

1. Copy scripts:
```bash
sudo cp zabbix/scripts/* /usr/lib/zabbix/externalscripts/
sudo chmod +x /usr/lib/zabbix/externalscripts/check_*
```

2. Copy user parameters:
```bash
sudo cp zabbix/userparameters/userparameter_kopia.conf /etc/zabbix/zabbix_agentd.d/
sudo systemctl restart zabbix-agent
```

3. Import template:
- Open Zabbix web interface
- Go to Configuration → Templates
- Import template_kopia.yaml

## Monitored Items

### Backup Status
- Last backup completion time
- Backup validation status
- Backup size and count

### Connectivity
- NAS connection status
- Client connectivity
- Repository access

### Repository
- Repository size
- Available space
- Integrity status

## Triggers

### High Priority
- 🔴 Backup validation failed
- 🔴 NAS connection lost
- 🔴 Repository corruption detected

### Warning
- 🟡 Backup older than 24h
- 🟡 Low disk space on repository
- 🟡 Client connection issues

## Macros

| Macro | Description | Default |
|-------|-------------|---------|
| {$BACKUP_MAX_AGE} | Maximum backup age in hours | 24 |
| {$REPO_SPACE_WARN} | Repository space warning % | 80 |
| {$REPO_SPACE_CRIT} | Repository space critical % | 90 |

## Testing

Test monitoring setup:
```bash
# Test NAS connection check
/usr/lib/zabbix/externalscripts/check_nas_connection.sh

# Test backup status
/usr/lib/zabbix/externalscripts/check_kopia_backup.sh

# Test repository check
/usr/lib/zabbix/externalscripts/check_repository.sh
```

### 2. Configure Environment
```bash
# Add to your .env file:
KOPIA_CONTAINER_NAME=kopia-server    # Container name for monitoring
ZABBIX_EXTERNAL_SCRIPTS=/usr/lib/zabbix/externalscripts  # Zabbix scripts path
ZABBIX_AGENT_CONFIG=/etc/zabbix/zabbix_agentd.d         # Zabbix agent config path
```

### 3. Deploy Monitoring Scripts
```bash
# Create directories
sudo mkdir -p "${ZABBIX_EXTERNAL_SCRIPTS}"
sudo mkdir -p "${ZABBIX_AGENT_CONFIG}"

# Copy scripts
sudo cp zabbix/scripts/* "${ZABBIX_EXTERNAL_SCRIPTS}/"
sudo chmod +x "${ZABBIX_EXTERNAL_SCRIPTS}"/check_*

# Copy user parameters
sudo cp zabbix/userparameters/* "${ZABBIX_AGENT_CONFIG}/"

# Restart Zabbix agent
sudo systemctl restart zabbix-agent
``` 