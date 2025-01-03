#!/bin/bash

# Configuration
BACKUP_DIR="/var/lib/kopia/dashboards_backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
GRAFANA_URL=${GRAFANA_URL:-"http://grafana:3000"}
GRAFANA_API_KEY=${GRAFANA_API_KEY:-""}
ZABBIX_URL=${ZABBIX_URL:-"http://zabbix/zabbix"}
ZABBIX_USER=${ZABBIX_USER:-"admin"}
ZABBIX_PASSWORD=${ZABBIX_PASSWORD:-"password"}

# Create backup directory structure
mkdir -p "${BACKUP_DIR}/${TIMESTAMP}/grafana"
mkdir -p "${BACKUP_DIR}/${TIMESTAMP}/zabbix"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to log messages
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Backup Grafana dashboards
backup_grafana() {
    log "Starting Grafana dashboards backup..."
    
    # Get list of all dashboards
    DASHBOARDS=$(curl -s -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
        "${GRAFANA_URL}/api/search?type=dash-db" | jq -r '.[] | .uid')
    
    if [ $? -ne 0 ]; then
        error "Failed to get Grafana dashboards list"
        return 1
    }
    
    # Export each dashboard
    for uid in $DASHBOARDS; do
        DASHBOARD_JSON=$(curl -s -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
            "${GRAFANA_URL}/api/dashboards/uid/${uid}")
        
        if [ $? -eq 0 ]; then
            TITLE=$(echo $DASHBOARD_JSON | jq -r '.dashboard.title' | sed 's/[^a-zA-Z0-9]/_/g')
            echo $DASHBOARD_JSON | jq '.' > "${BACKUP_DIR}/${TIMESTAMP}/grafana/${TITLE}.json"
            log "Backed up Grafana dashboard: ${TITLE}"
        else
            error "Failed to backup dashboard with UID: ${uid}"
        fi
    done
    
    # Backup datasources
    curl -s -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
        "${GRAFANA_URL}/api/datasources" | jq '.' > "${BACKUP_DIR}/${TIMESTAMP}/grafana/datasources.json"
    
    # Backup alert rules
    curl -s -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
        "${GRAFANA_URL}/api/ruler/grafana/api/v1/rules" | jq '.' > "${BACKUP_DIR}/${TIMESTAMP}/grafana/alert_rules.json"
}

# Backup Zabbix dashboards
backup_zabbix() {
    log "Starting Zabbix dashboards backup..."
    
    # Get authentication token
    AUTH_TOKEN=$(curl -s -H "Content-Type: application/json" -X POST \
        "${ZABBIX_URL}/api_jsonrpc.php" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"user.login\",
            \"params\": {
                \"user\": \"${ZABBIX_USER}\",
                \"password\": \"${ZABBIX_PASSWORD}\"
            },
            \"id\": 1
        }" | jq -r '.result')
    
    if [ -z "$AUTH_TOKEN" ]; then
        error "Failed to authenticate with Zabbix"
        return 1
    fi
    
    # Export dashboards
    curl -s -H "Content-Type: application/json" -X POST \
        "${ZABBIX_URL}/api_jsonrpc.php" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"dashboard.get\",
            \"params\": {
                \"output\": \"extend\"
            },
            \"auth\": \"${AUTH_TOKEN}\",
            \"id\": 2
        }" | jq '.' > "${BACKUP_DIR}/${TIMESTAMP}/zabbix/dashboards.json"
    
    # Export templates
    curl -s -H "Content-Type: application/json" -X POST \
        "${ZABBIX_URL}/api_jsonrpc.php" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"template.get\",
            \"params\": {
                \"output\": \"extend\",
                \"selectDashboards\": \"extend\"
            },
            \"auth\": \"${AUTH_TOKEN}\",
            \"id\": 3
        }" | jq '.' > "${BACKUP_DIR}/${TIMESTAMP}/zabbix/templates.json"
    
    # Logout
    curl -s -H "Content-Type: application/json" -X POST \
        "${ZABBIX_URL}/api_jsonrpc.php" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"user.logout\",
            \"params\": [],
            \"auth\": \"${AUTH_TOKEN}\",
            \"id\": 4
        }" > /dev/null
}

# Create archive
create_archive() {
    log "Creating backup archive..."
    cd "${BACKUP_DIR}"
    tar -czf "dashboards_${TIMESTAMP}.tar.gz" "${TIMESTAMP}"
    rm -rf "${BACKUP_DIR}/${TIMESTAMP}"
    log "Backup archive created: ${BACKUP_DIR}/dashboards_${TIMESTAMP}.tar.gz"
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups..."
    find "${BACKUP_DIR}" -name "dashboards_*.tar.gz" -mtime +30 -delete
}

# Main execution
main() {
    log "Starting dashboards backup..."
    
    backup_grafana
    backup_zabbix
    create_archive
    cleanup_old_backups
    
    log "Backup completed successfully!"
}

# Run main function
main 