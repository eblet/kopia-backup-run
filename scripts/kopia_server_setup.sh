#!/bin/bash
set -euo pipefail

# Load environment variables
if [ ! -f .env ]; then
    echo "ERROR: .env file not found"
    exit 1
fi
source .env

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Validate environment variables
validate_env() {
    log "Validating environment variables..."
    
    local required_vars=(
        "KOPIA_REPO_PASSWORD"
        "KOPIA_SERVER_USERNAME"
        "KOPIA_SERVER_PASSWORD"
        "KOPIA_BASE_DIR"
        "KOPIA_REPO_PATH"
        "NAS_IP"
        "NAS_SHARE"
        "NAS_MOUNT_PATH"
        "KOPIA_SERVER_PORT"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log "ERROR: Required variable $var is not set"
            exit 1
        fi
    done

    # Validate security requirements
    if [[ ${#KOPIA_REPO_PASSWORD} -lt 16 ]]; then
        log "ERROR: KOPIA_REPO_PASSWORD must be at least 16 characters"
        exit 1
    fi
    if [[ ${#KOPIA_SERVER_PASSWORD} -lt 16 ]]; then
        log "ERROR: KOPIA_SERVER_PASSWORD must be at least 16 characters"
        exit 1
    fi
    if [[ ${#KOPIA_SERVER_USERNAME} -lt 8 ]]; then
        log "ERROR: KOPIA_SERVER_USERNAME must be at least 8 characters"
        exit 1
    fi

    # Validate port
    if ! [[ "${KOPIA_SERVER_PORT}" =~ ^[0-9]+$ ]] || \
       [ "${KOPIA_SERVER_PORT}" -lt 1 ] || \
       [ "${KOPIA_SERVER_PORT}" -gt 65535 ]; then
        log "ERROR: Invalid KOPIA_SERVER_PORT value (must be between 1-65535)"
        exit 1
    fi
}

# Check system requirements and dependencies
check_system_requirements() {
    log "Checking system requirements..."
    
    # Check root privileges
    if [ "$EUID" -ne 0 ]; then 
        log "ERROR: This script must be run as root"
        exit 1
    fi

    # Check required packages
    local packages=(nfs-common curl docker.io docker-compose)
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$pkg"; then
            log "Installing $pkg..."
            apt-get update && apt-get install -y "$pkg"
        fi
    done

    # Check system resources
    local min_memory=2048  # 2GB in MB
    local available_memory=$(free -m | awk '/^Mem:/{print $2}')
    if [ "${available_memory}" -lt "${min_memory}" ]; then
        log "WARNING: System has less than 2GB RAM (${available_memory}MB)"
    fi

    # Check disk space
    local min_space=10240  # 10GB in MB
    local available_space=$(df -m "${KOPIA_BASE_DIR}" | awk 'NR==2 {print $4}')
    if [ "${available_space}" -lt "${min_space}" ]; then
        log "WARNING: Less than 10GB free space available on ${KOPIA_BASE_DIR}"
    fi

    # Check Docker service
    if ! systemctl is-active --quiet docker; then
        log "Starting Docker service..."
        systemctl start docker
    fi
}

# Setup required directories
setup_directories() {
    log "Creating required directories..."
    
    local dirs=(
        "${KOPIA_BASE_DIR}"
        "${KOPIA_REPO_PATH}"
        "${NAS_MOUNT_PATH}"
        "/var/log/kopia"
        "${KOPIA_CACHE_DIR:-/var/cache/kopia}"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
        chmod 750 "${dir}"
    done
}

# Verify NAS connectivity and mount
setup_nas() {
    log "Setting up NAS connection..."

    # Check NAS connectivity
    if ! ping -c 1 "${NAS_IP}" &> /dev/null; then
        log "ERROR: Cannot reach NAS at ${NAS_IP}"
        exit 1
    fi

    # Verify NFS export
    if ! showmount -e "${NAS_IP}" | grep -q "${NAS_SHARE}"; then
        log "ERROR: NFS share ${NAS_SHARE} not found on ${NAS_IP}"
        exit 1
    fi

    # Setup mount
    if ! mountpoint -q "${NAS_MOUNT_PATH}"; then
        log "Mounting NAS share..."
        if ! grep -q "${NAS_MOUNT_PATH}" /etc/fstab; then
            echo "${NAS_IP}:${NAS_SHARE} ${NAS_MOUNT_PATH} nfs ${NAS_MOUNT_OPTIONS:-defaults} 0 0" >> /etc/fstab
        fi
        
        if ! timeout "${NAS_TIMEOUT:-30}" mount -a; then
            log "ERROR: Failed to mount NAS"
            exit 1
        fi
    fi
}

# Initialize Kopia repository
init_repository() {
    log "Initializing Kopia repository..."
    
    if [ ! -f "${KOPIA_REPO_PATH}/.kopia" ]; then
        echo "${KOPIA_REPO_PASSWORD}" | docker run --rm \
            -v "${KOPIA_REPO_PATH}:${KOPIA_REPO_PATH}" \
            -v "${KOPIA_CACHE_DIR:-/var/cache/kopia}:/app/cache" \
            kopia/kopia:latest repository create filesystem \
            --path="${KOPIA_REPO_PATH}" \
            --cache-directory=/app/cache \
            --max-cache-size="${KOPIA_CACHE_SIZE:-5G}"
    else
        log "Repository already exists at ${KOPIA_REPO_PATH}"
    fi
}

# Create and configure systemd services
setup_systemd_services() {
    log "Setting up systemd services..."
    
    # Create service files
    create_server_service
    create_nas_sync_service
    create_nas_sync_timer
    create_logrotate_config
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable and start services
    systemctl enable --now kopia-server
    systemctl enable --now kopia-nas-sync.timer
    
    # Verify services
    if ! systemctl is-active --quiet kopia-server; then
        log "ERROR: Failed to start kopia-server service"
        journalctl -u kopia-server --no-pager -n 50
        exit 1
    fi
}

# Main execution
main() {
    log "Starting Kopia server setup..."
    
    validate_env
    check_system_requirements
    setup_directories
    setup_nas
    init_repository
    setup_systemd_services
    
    log "Kopia server setup completed successfully!"
    log "Server URL: ${KOPIA_SECURE_MODE:+https://}${KOPIA_SECURE_MODE:-http://}$(hostname -I | awk '{print $1}'):${KOPIA_SERVER_PORT}"
}

# Run main function
main "$@"