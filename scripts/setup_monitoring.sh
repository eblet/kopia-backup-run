#!/bin/bash
set -euo pipefail

# Enhanced logging with colors
log() {
    local level=$1
    local message=$2
    local color=""
    case $level in
        "INFO") color="\033[0;32m" ;;  # Green
        "WARN") color="\033[1;33m" ;;  # Yellow
        "ERROR") color="\033[0;31m" ;; # Red
    esac
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}\033[0m"
}

# Check dependencies
check_dependencies() {
    log "INFO" "Checking dependencies..."
    
    # Required commands
    local commands=(docker docker-compose curl jq)
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log "ERROR" "$cmd is required but not installed"
            exit 1
        fi
    done

    # Check Docker networks
    if ! docker network inspect kopia_network >/dev/null 2>&1; then
        log "ERROR" "Kopia network not found. Is Kopia server running?"
        exit 1
    fi
}

# Check disk space with specific paths
check_disk_space() {
    log "INFO" "Checking disk space requirements..."
    
    local required_spaces=(
        "/var/lib/prometheus:10240"  # 10GB for Prometheus
        "/var/lib/grafana:1024"      # 1GB for Grafana
        "/var/log/kopia:1024"        # 1GB for logs
    )

    for space in "${required_spaces[@]}"; do
        local path="${space%%:*}"
        local required_mb="${space##*:}"
        local available_mb=$(df -m "$path" | awk 'NR==2 {print $4}')
        
        if [ "$available_mb" -lt "$required_mb" ]; then
            log "ERROR" "Insufficient space in $path. Required: ${required_mb}MB, Available: ${available_mb}MB"
            return 1
        fi
        log "INFO" "Space check passed for $path (${available_mb}MB available)"
    done
}

# Rollback function
rollback() {
    log "WARN" "Rolling back changes..."
    docker-compose -f monitoring/docker-compose.monitoring.yml down -v
    rm -rf "${PROMETHEUS_DATA_DIR:-/var/lib/prometheus}"/*
    rm -rf "${GRAFANA_DATA_DIR:-/var/lib/grafana}"/*
}

setup_prometheus() {
    log "INFO" "Setting up Prometheus monitoring..."
    
    # Create required directories
    sudo mkdir -p "${PROMETHEUS_DATA_DIR:-/var/lib/prometheus}"
    sudo mkdir -p "${GRAFANA_DATA_DIR:-/var/lib/grafana}"
    
    # Set permissions
    sudo chown -R "${PROM_USER:-65534}:${PROM_GROUP:-65534}" "${PROMETHEUS_DATA_DIR:-/var/lib/prometheus}"
    sudo chown -R "${GRAFANA_USER:-472}:${GRAFANA_GROUP:-472}" "${GRAFANA_DATA_DIR:-/var/lib/grafana}"
    
    # Create networks if they don't exist
    docker network inspect "${MONITORING_NETWORK_NAME:-monitoring_network}" >/dev/null 2>&1 || \
        docker network create "${MONITORING_NETWORK_NAME:-monitoring_network}"
    
    # Check if Kopia is running
    if ! docker ps | grep -q kopia-server; then
        echo "WARNING: Kopia server is not running"
        echo "Some metrics may not be available"
    fi

    # Check disk space
    MIN_SPACE=1000000  # 1GB
    available=$(df -k "${PROMETHEUS_DATA_DIR:-/var/lib/prometheus}" | awk 'NR==2 {print $4}')
    if [ "$available" -lt "$MIN_SPACE" ]; then
        echo "WARNING: Low disk space for Prometheus data"
    fi
    
    # Deploy monitoring stack
    docker-compose -f monitoring/docker-compose.monitoring.yml up -d
    
    echo "Prometheus monitoring setup completed"
}

setup_zabbix() {
    log "INFO" "Setting up Zabbix monitoring..."
    (cd monitoring/zabbix && ./setup.sh)
}

# Main execution with rollback
main() {
    # Create temporary file for tracking progress
    local progress_file=$(mktemp)
    trap 'rm -f $progress_file' EXIT

    log "INFO" "Starting monitoring setup..."
    
    # Check requirements first
    check_dependencies || exit 1
    check_disk_space || exit 1
    echo "dependencies_checked" > "$progress_file"

    # Setup monitoring based on type
    case "${MONITORING_TYPE:-none}" in
        "all")
            if ! setup_prometheus; then
                log "ERROR" "Prometheus setup failed"
                [ -f "$progress_file" ] && rollback
                exit 1
            fi
            echo "prometheus_setup" >> "$progress_file"

            if ! setup_zabbix; then
                log "ERROR" "Zabbix setup failed"
                [ -f "$progress_file" ] && rollback
                exit 1
            fi
            echo "zabbix_setup" >> "$progress_file"
            ;;
        "prometheus")
            if ! setup_prometheus; then
                log "ERROR" "Prometheus setup failed"
                [ -f "$progress_file" ] && rollback
                exit 1
            fi
            ;;
        "zabbix")
            if ! setup_zabbix; then
                log "ERROR" "Zabbix setup failed"
                [ -f "$progress_file" ] && rollback
                exit 1
            fi
            ;;
        "none")
            log "INFO" "Monitoring disabled"
            exit 0
            ;;
        *)
            log "ERROR" "Invalid MONITORING_TYPE: ${MONITORING_TYPE}"
            exit 1
            ;;
    esac

    verify_deployment
    log "INFO" "Monitoring setup completed successfully!"
}

# Run main with error handling
trap 'log "ERROR" "Script failed on line $LINENO"' ERR
main "$@"