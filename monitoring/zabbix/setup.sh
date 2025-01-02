#!/bin/bash
set -euo pipefail

# Find and load parent .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../" && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [ ! -f "${ENV_FILE}" ]; then
    echo "ERROR: .env file not found in ${ROOT_DIR}"
    exit 1
fi
source "${ENV_FILE}"

# Check Docker networks
docker network inspect kopia_network >/dev/null 2>&1 || \
    docker network create kopia_network

# Check requirements
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required"; exit 1; }

# Create directories
sudo mkdir -p "${ZABBIX_EXTERNAL_SCRIPTS}"
sudo mkdir -p "${ZABBIX_AGENT_CONFIG}"

# Copy files
sudo cp scripts/* "${ZABBIX_EXTERNAL_SCRIPTS}/"
sudo chmod +x "${ZABBIX_EXTERNAL_SCRIPTS}"/check_*
sudo cp userparameters/* "${ZABBIX_AGENT_CONFIG}/"

# Set permissions
sudo usermod -aG docker zabbix
sudo setfacl -R -m u:zabbix:rx "${KOPIA_BASE_DIR}"
sudo setfacl -R -m u:zabbix:rx "${KOPIA_LOG_DIR}"

# Restart Zabbix agent
sudo systemctl restart zabbix-agent

echo "Monitoring setup completed successfully!"
echo "Don't forget to import the template in Zabbix web interface" 