#!/bin/bash
set -euo pipefail

# Find required binaries
DOCKER_BIN=$(which docker) || { echo "ERROR: docker not found"; exit 1; }
DOCKER_COMPOSE_BIN=$(which docker compose) || { echo "ERROR: docker compose not found"; exit 1; }

# Version requirements
REQUIRED_DOCKER_VERSION="20.10.0"
REQUIRED_COMPOSE_VERSION="2.0.0"
MIN_MEMORY_MB=2048  # 2GB
MIN_DISK_SPACE_MB=10240  # 10GB

# Load environment variables
if [ ! -f .env ]; then
    echo "ERROR: .env file not found"
    exit 1
fi
source .env

# Enhanced logging function with levels
log() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}"
}

# Check software versions
check_versions() {
    log "INFO" "Checking software versions..."
    
    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        log "ERROR" "Docker is not installed"
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! docker compose version >/dev/null 2>&1; then
        log "ERROR" "Docker Compose V2 is not installed"
        exit 1
    fi
    
    # Just log versions for information
    log "INFO" "Docker version: $(docker --version)"
    log "INFO" "Docker Compose version: $(docker compose version)"
}

# Enhanced system requirements check
check_system_requirements() {
    log "INFO" "Checking system requirements..."
    
    # Check root privileges
    if [ "$EUID" -ne 0 ]; then 
        log "ERROR" "This script must be run as root"
        exit 1
    fi

    # Check required packages with version logging
    local packages=(nfs-common curl docker.io docker-compose-plugin)
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$pkg"; then
            log "INFO" "Installing ${pkg}..."
            apt-get update && apt-get install -y "$pkg"
        fi
        local version=$(dpkg -l | grep "^ii.*$pkg" | awk '{print $3}')
        log "INFO" "Found ${pkg} version ${version}"
    done

    # Check system resources with detailed reporting
    local available_memory=$(free -m | awk '/^Mem:/{print $2}')
    if [ "${available_memory}" -lt "${MIN_MEMORY_MB}" ]; then
        log "WARNING" "System has less than ${MIN_MEMORY_MB}MB RAM (${available_memory}MB)"
    fi
    log "INFO" "Available memory: ${available_memory}MB"

    # Check disk space for all critical directories
    local dirs=(
        "${KOPIA_BASE_DIR}"
        "${KOPIA_LOG_DIR}"
        "${NAS_MOUNT_PATH}"
    )

    for dir in "${dirs[@]}"; do
        local available_space=$(df -m "$(dirname "$dir")" | awk 'NR==2 {print $4}')
        if [ "${available_space}" -lt "${MIN_DISK_SPACE_MB}" ]; then
            log "WARNING" "Less than ${MIN_DISK_SPACE_MB}MB free space available on ${dir} (${available_space}MB)"
        fi
        log "INFO" "Available space for ${dir}: ${available_space}MB"
    done

    # Check Docker service with enhanced error handling
    if ! systemctl is-active --quiet docker; then
        log "INFO" "Starting Docker service..."
        if ! systemctl start docker; then
            log "ERROR" "Failed to start Docker service"
            journalctl -u docker --no-pager -n 50
            exit 1
        fi
    fi
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

    if [ "${KOPIA_SECURE_MODE}" = "true" ] && [ ! -f "${KOPIA_TLS_CERT_PATH}" ]; then
        log "ERROR: KOPIA_TLS_CERT_PATH not found but KOPIA_SECURE_MODE is true"
        exit 1
    fi

    if [ -z "${KOPIA_CONTAINER_CONFIG_DIR}" ] || [ -z "${KOPIA_CONTAINER_CACHE_DIR}" ]; then
        log "ERROR: Container paths not set"
        exit 1
    fi
}

# Setup required directories
setup_directories() {
    log "INFO" "Creating and configuring directories..."
    
    local dirs=(
        "${KOPIA_BASE_DIR}"
        "${KOPIA_REPO_PATH}"
        "${NAS_MOUNT_PATH}"
        "${KOPIA_LOG_DIR}"
        "${KOPIA_CACHE_DIR}"
    )

    for dir in "${dirs[@]}"; do
        if ! mkdir -p "${dir}"; then
            log "ERROR" "Failed to create directory: ${dir}"
            exit 1
        fi
        
        if ! chmod 750 "${dir}"; then
            log "ERROR" "Failed to set permissions on: ${dir}"
            exit 1
        fi
        
        log "INFO" "Created directory ${dir} with permissions 750"
    done

    # Verify write permissions
    for dir in "${dirs[@]}"; do
        if ! touch "${dir}/.write_test" 2>/dev/null; then
            log "ERROR" "Directory ${dir} is not writable"
            exit 1
        fi
        rm -f "${dir}/.write_test"
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

# Create server systemd service
create_server_service() {
    log "Creating Kopia server systemd service..."
    
    cat > /etc/systemd/system/kopia-server.service << EOF
[Unit]
Description=Kopia Backup Server
After=docker.service network.target
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=${PWD}
Environment=COMPOSE_FILE=docker/docker-compose.server.yml
ExecStartPre=-/usr/local/bin/docker compose down
ExecStart=/usr/local/bin/docker compose up --remove-orphans
ExecStop=/usr/local/bin/docker compose down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 /etc/systemd/system/kopia-server.service
}

# Create NAS sync service
create_nas_sync_service() {
    log "Creating NAS sync service..."
    
    cat > /etc/systemd/system/kopia-nas-sync.service << EOF
[Unit]
Description=Kopia NAS Sync Service
After=kopia-server.service
Requires=kopia-server.service

[Service]
Type=oneshot
Environment=KOPIA_PASSWORD=${KOPIA_REPO_PASSWORD}
ExecStart=/usr/bin/docker run --rm \
    --network kopia_network \
    -v ${KOPIA_BASE_DIR}:${KOPIA_BASE_DIR}:rw \
    -v ${NAS_MOUNT_PATH}:${NAS_MOUNT_PATH}:rw \
    -v ${KOPIA_LOG_DIR}:${KOPIA_LOG_DIR}:rw \
    -v ${KOPIA_CACHE_DIR}:${KOPIA_CONTAINER_CACHE_DIR}:rw \
    kopia/kopia:latest snapshot create ${KOPIA_REPO_PATH} \
    --target-path=${NAS_MOUNT_PATH}/kopia-repo \
    --compression=zstd-max \
    --parallel=${KOPIA_PARALLEL_SERVER:-2} \
    --check-integrity=${BACKUP_VERIFY:-true}
StandardOutput=append:${KOPIA_LOG_DIR}/nas-sync.log
StandardError=append:${KOPIA_LOG_DIR}/nas-sync-error.log
Nice=19
IOSchedulingClass=2
IOSchedulingPriority=7

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 /etc/systemd/system/kopia-nas-sync.service
}

# Create NAS sync timer
create_nas_sync_timer() {
    log "Creating NAS sync timer..."
    
    cat > /etc/systemd/system/kopia-nas-sync.timer << EOF
[Unit]
Description=Kopia NAS Sync Timer

[Timer]
OnCalendar=${SERVER_SYNC_TIME:-*-*-* 05:00:00}
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
EOF

    chmod 644 /etc/systemd/system/kopia-nas-sync.timer
}

# Create logrotate configuration
create_logrotate_config() {
    log "Creating logrotate configuration..."
    
    cat > /etc/logrotate.d/kopia << EOF
${KOPIA_LOG_DIR}/*.log {
    daily
    rotate ${LOG_MAX_FILES:-7}
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
    size ${LOG_MAX_SIZE:-100M}
    postrotate
        systemctl try-reload-or-restart kopia-server.service
    endscript
}
EOF

    chmod 644 /etc/logrotate.d/kopia
}

# Create cleanup script
create_cleanup_script() {
    log "Creating cleanup script..."
    
    cat > /usr/local/bin/kopia-cleanup << EOF
#!/bin/bash
set -euo pipefail

# Clean old snapshots
docker exec kopia-server kopia snapshot list \
    --source-path=${KOPIA_REPO_PATH} \
    --maxage=${BACKUP_RETENTION_DAYS:-7}d \
    --delete

# Maintenance tasks
docker exec kopia-server kopia maintenance run \
    --full \
    --safety=full
EOF

    chmod 755 /usr/local/bin/kopia-cleanup
    
    # Create cleanup timer
    cat > /etc/systemd/system/kopia-cleanup.timer << EOF
[Unit]
Description=Kopia Cleanup Timer

[Timer]
OnCalendar=weekly
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

    chmod 644 /etc/systemd/system/kopia-cleanup.timer
    
    # Create cleanup service
    cat > /etc/systemd/system/kopia-cleanup.service << EOF
[Unit]
Description=Kopia Cleanup Service
After=kopia-server.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kopia-cleanup
StandardOutput=append:${KOPIA_LOG_DIR}/cleanup.log
StandardError=append:${KOPIA_LOG_DIR}/cleanup-error.log

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 /etc/systemd/system/kopia-cleanup.service
}

# Initialize Kopia repository
init_repository() {
    log "Initializing Kopia repository..."
    
    if [ ! -f "${KOPIA_REPO_PATH}/.kopia" ]; then
        echo "${KOPIA_REPO_PASSWORD}" | docker run --rm \
            -v "${KOPIA_REPO_PATH}:${KOPIA_REPO_PATH}" \
            -v "${KOPIA_CACHE_DIR}:${KOPIA_CONTAINER_CACHE_DIR}" \
            kopia/kopia:latest repository create filesystem \
            --path="${KOPIA_REPO_PATH}" \
            --cache-directory="${KOPIA_CONTAINER_CACHE_DIR}" \
            --max-cache-size="${KOPIA_CACHE_SIZE:-5G}"
    else
        log "Repository already exists at ${KOPIA_REPO_PATH}"
    fi
}

# Create and configure systemd services
setup_systemd_services() {
    log "Setting up systemd services..."
    
    # Create all service files
    create_server_service
    create_nas_sync_service
    create_nas_sync_timer
    create_logrotate_config
    create_cleanup_script
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable and start services
    systemctl enable --now kopia-server.service
    systemctl enable --now kopia-nas-sync.timer
    systemctl enable --now kopia-cleanup.timer
    
    # Verify services
    local services=(kopia-server kopia-nas-sync.timer kopia-cleanup.timer)
    for service in "${services[@]}"; do
        if ! systemctl is-enabled --quiet "$service"; then
            log "ERROR: Failed to enable $service"
            journalctl -u "$service" --no-pager -n 50
            exit 1
        fi
    done
    
    if ! systemctl is-active --quiet kopia-server; then
        log "ERROR: Failed to start kopia-server service"
        journalctl -u kopia-server --no-pager -n 50
        exit 1
    fi
    
    log "All services configured and started successfully"
}

# Enhanced network checks
check_network() {
    log "INFO" "Checking network connectivity..."

    # Check Docker network
    if ! $DOCKER_BIN network ls | grep -q "kopia_network"; then
        log "INFO" "Creating Docker network: kopia_network"
        if ! $DOCKER_BIN network create kopia_network; then
            log "ERROR" "Failed to create Docker network"
            exit 1
        fi
    fi

    # Check NAS connectivity with timeout
    if ! timeout 5 ping -c 1 "${NAS_IP}" &> /dev/null; then
        log "ERROR" "Cannot reach NAS at ${NAS_IP}"
        exit 1
    fi

    # Check NFS connectivity with enhanced error handling
    if ! showmount -e "${NAS_IP}" | grep -q "${NAS_SHARE}"; then
        log "ERROR" "NFS share ${NAS_SHARE} not found on ${NAS_IP}"
        log "DEBUG" "Available shares on ${NAS_IP}:"
        showmount -e "${NAS_IP}" || true
        exit 1
    fi
}

# Main execution with enhanced flow
main() {
    log "INFO" "Starting Kopia server setup..."
    
    check_versions
    validate_env
    check_system_requirements
    check_network
    setup_directories
    setup_nas
    init_repository
    setup_systemd_services
    
    log "INFO" "Kopia server setup completed successfully!"
    log "INFO" "Server URL: ${KOPIA_SECURE_MODE:+https://}${KOPIA_SECURE_MODE:-http://}$(hostname -I | awk '{print $1}'):${KOPIA_SERVER_PORT}"
    
    # Final status check
    if systemctl is-active --quiet kopia-server; then
        log "INFO" "Server is running and healthy"
    else
        log "WARNING" "Server setup completed but service is not running"
        log "DEBUG" "Check logs with: journalctl -u kopia-server"
    fi
}

# Enhanced error handling
trap 'log "ERROR" "Script failed on line $LINENO"; exit 1' ERR

# Run main function
main "$@"