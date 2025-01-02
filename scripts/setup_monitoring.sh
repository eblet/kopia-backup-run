#!/bin/bash
set -euo pipefail

# Load environment
source .env

# Setup monitoring based on configuration
setup_prometheus() {
    echo "Setting up Prometheus monitoring..."
    
    # Create required directories
    sudo mkdir -p "${PROMETHEUS_DATA_DIR:-/var/lib/prometheus}"
    sudo mkdir -p "${GRAFANA_DATA_DIR:-/var/lib/grafana}"
    
    # Set permissions
    sudo chown -R "${PROM_USER:-65534}:${PROM_GROUP:-65534}" "${PROMETHEUS_DATA_DIR:-/var/lib/prometheus}"
    sudo chown -R "${GRAFANA_USER:-472}:${GRAFANA_GROUP:-472}" "${GRAFANA_DATA_DIR:-/var/lib/grafana}"
    
    # Create networks if they don't exist
    docker network inspect "${MONITORING_NETWORK_NAME:-monitoring_network}" >/dev/null 2>&1 || \
        docker network create "${MONITORING_NETWORK_NAME:-monitoring_network}"
    
    # Deploy monitoring stack
    docker-compose -f monitoring/docker-compose.monitoring.yml up -d
    
    echo "Prometheus monitoring setup completed"
}

setup_zabbix() {
    echo "Setting up Zabbix monitoring..."
    (cd monitoring/zabbix && ./setup.sh)
}

# Check disk space
MIN_SPACE=1000000  # 1GB
available=$(df -k "${PROMETHEUS_DATA_DIR:-/var/lib/prometheus}" | awk 'NR==2 {print $4}')
if [ "$available" -lt "$MIN_SPACE" ]; then
    echo "ERROR: Insufficient disk space"
    exit 1
fi

# Check if Kopia is running
if ! docker ps | grep -q kopia-server; then
    echo "ERROR: Kopia server is not running"
    exit 1
fi

# Main setup
case "${MONITORING_TYPE:-all}" in
    "all")
        echo "Setting up both Zabbix and Prometheus monitoring..."
        setup_zabbix
        setup_prometheus
        ;;
    "zabbix")
        setup_zabbix
        ;;
    "prometheus")
        setup_prometheus
        ;;
    "none")
        echo "Monitoring disabled"
        ;;
    *)
        echo "Invalid MONITORING_TYPE: ${MONITORING_TYPE}"
        exit 1
        ;;
esac

echo "Monitoring setup completed successfully!"