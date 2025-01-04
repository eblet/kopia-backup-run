#!/bin/bash

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

# Configuration
BACKUP_DIR="/var/lib/kopia/maintenance"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup dashboards and configs
backup() {
    log "Starting backup..."
    
    # Create backup directory
    mkdir -p "${BACKUP_DIR}/${TIMESTAMP}"
    
    # Backup Grafana dashboards
    if curl -s "http://localhost:3000/api/health" > /dev/null; then
        log "Backing up Grafana dashboards..."
        ./scripts/backup_dashboards.sh
    fi
    
    # Backup configurations
    log "Backing up configurations..."
    tar -czf "${BACKUP_DIR}/${TIMESTAMP}/configs.tar.gz" \
        .env docker/ monitoring/
        
    # Cleanup old backups (older than 30 days)
    find "${BACKUP_DIR}" -type d -mtime +30 -exec rm -rf {} \;
    
    log "Backup completed: ${BACKUP_DIR}/${TIMESTAMP}"
}

# Update system components
update() {
    log "Starting system update..."
    
    # Pull new images
    docker compose pull
    
    # Restart services
    docker compose up -d
    
    # Cleanup
    docker system prune -f
    
    log "Update completed"
}

# Verify system health
verify() {
    log "Verifying system health..."
    
    # Check containers
    docker compose ps
    
    # Check monitoring
    if curl -s "http://localhost:9090/-/healthy" > /dev/null; then
        log "Prometheus: OK"
    else
        error "Prometheus: Failed"
    fi
    
    if curl -s "http://localhost:3000/api/health" > /dev/null; then
        log "Grafana: OK"
    else
        error "Grafana: Failed"
    fi
    
    # Check Kopia
    if docker exec kopia-server kopia repository status > /dev/null; then
        log "Kopia repository: OK"
    else
        error "Kopia repository: Failed"
    fi
}

# Rotate logs
rotate_logs() {
    log "Starting log rotation..."
    
    # Compress logs older than 30 days
    find /var/log/kopia -name "*.log" -mtime +30 \
        -exec gzip {} \;
    
    # Remove logs older than 90 days
    find /var/log/kopia -name "*.gz" -mtime +90 \
        -exec rm {} \;
        
    log "Log rotation completed"
}

# Main
case "$1" in
    "backup")
        backup
        ;;
    "update")
        update
        ;;
    "verify")
        verify
        ;;
    "logs")
        rotate_logs
        ;;
    *)
        echo "Usage: $0 {backup|update|verify|logs}"
        echo
        echo "Commands:"
        echo "  backup  - Backup dashboards and configurations"
        echo "  update  - Update system components"
        echo "  verify  - Verify system health"
        echo "  logs    - Rotate log files"
        exit 1
        ;;
esac 