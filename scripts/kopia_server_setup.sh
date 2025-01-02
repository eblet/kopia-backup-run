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

# Validate environment
validate_env() {
    local required_vars=(
        "KOPIA_REPO_PASSWORD"
        "KOPIA_SERVER_USERNAME"
        "KOPIA_SERVER_PASSWORD"
        "KOPIA_BASE_DIR"
        "KOPIA_REPO_PATH"
        "NAS_IP"
        "NAS_SHARE"
        "NAS_MOUNT_PATH"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log "ERROR: $var is not set"
            exit 1
        fi
    done

    # Validate passwords
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
        log "ERROR: Invalid KOPIA_SERVER_PORT value"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then 
        log "Please run as root"
        exit 1
    fi

    # Check required packages
    local packages=(nfs-common curl)
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
}

# Setup directories
setup_dirs() {
    log "Creating required directories..."
    local dirs=(
        "${KOPIA_BASE_DIR}"
        "${KOPIA_REPO_PATH}"
        "${NAS_MOUNT_PATH}"
        "/var/log/kopia"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
        chmod 750 "${dir}"
    done
}

# Check NAS connectivity
check_nas() {
    log "Checking NAS connectivity..."
    
    # Check if NFS server is reachable
    if ! ping -c 1 "${NAS_IP}" &> /dev/null; then
        log "ERROR: Cannot reach NAS at ${NAS_IP}"
        exit 1
    fi

    # Check if NFS share exists
    if ! showmount -e "${NAS_IP}" | grep -q "${NAS_SHARE}"; then
        log "ERROR: NAS share ${NAS_SHARE} not found on ${NAS_IP}"
        exit 1
    fi
}

# Mount NAS
mount_nas() {
    log "Setting up NAS mount..."
    
    # Check if already mounted
    if mountpoint -q "${NAS_MOUNT_PATH}"; then
        log "NAS already mounted at ${NAS_MOUNT_PATH}"
        return 0
    fi

    # Add to fstab if not present
    if ! grep -q "${NAS_MOUNT_PATH}" /etc/fstab; then
        log "Adding NAS mount to fstab..."
        echo "${NAS_IP}:${NAS_SHARE} ${NAS_MOUNT_PATH} nfs ${NAS_MOUNT_OPTIONS:-defaults} 0 0" >> /etc/fstab
    fi

    # Try mounting with timeout
    log "Mounting NAS..."
    if ! timeout "${NAS_TIMEOUT:-30}" mount -a; then
        log "ERROR: Failed to mount NAS within ${NAS_TIMEOUT:-30} seconds"
        exit 1
    fi

    # Verify mount
    if ! mountpoint -q "${NAS_MOUNT_PATH}"; then
        log "ERROR: NAS mount verification failed"
        exit 1
    fi
}

# Create systemd services
create_systemd_services() {
    log "Creating systemd services..."
    
    # Kopia server service
    cat > /etc/systemd/system/kopia-server.service << EOF
[Unit]
Description=Kopia Backup Server
After=network.target Wants=network-online.target

[Service]
Type=simple
User=root
Environment=KOPIA_PASSWORD=${KOPIA_REPO_PASSWORD}
Environment=HOME=/root
WorkingDirectory=/root
ExecStart=/usr/bin/kopia server start \
    --address 0.0.0.0:${KOPIA_SERVER_PORT} \
    --server-username ${KOPIA_SERVER_USERNAME} \
    --server-password ${KOPIA_SERVER_PASSWORD} \
    ${KOPIA_SECURE_MODE:+--tls-generate-cert} \
    ${KOPIA_SECURE_MODE:-"--insecure"} \
    ${KOPIA_SERVER_ALLOWED_IPS:+--server-control-access=${KOPIA_SERVER_ALLOWED_IPS}} \
    --server-cache-directory=${KOPIA_CACHE_DIR:-/var/cache/kopia}
Restart=always
RestartSec=10
StandardOutput=append:/var/log/kopia/server.log
StandardError=append:/var/log/kopia/server-error.log
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    # Create log rotation config
    cat > /etc/logrotate.d/kopia << EOF
/var/log/kopia/*.log {
    daily
    rotate ${LOG_MAX_FILES:-7}
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
    size ${LOG_MAX_SIZE:-100M}
}
EOF

    # NAS sync script
    cat > /usr/local/bin/kopia-nas-sync.sh << EOF
#!/bin/bash
set -euo pipefail

# Sync with NAS
kopia snapshot create \
    --source-path=${KOPIA_REPO_PATH} \
    --target-path=${NAS_MOUNT_PATH}/kopia-repo \
    --compression=zstd-max \
    --parallel=${KOPIA_PARALLEL_SERVER:-2} \
    --check-integrity=${BACKUP_VERIFY:-true}

# Clean old backups in local storage
kopia snapshot list \
    --source-path=${KOPIA_REPO_PATH} \
    --maxage=${BACKUP_RETENTION_DAYS:-7}d \
    --delete
EOF

    chmod +x /usr/local/bin/kopia-nas-sync.sh

    # NAS sync service and timer
    cat > /etc/systemd/system/kopia-nas-sync.service << EOF
[Unit]
Description=Kopia NAS sync service
After=network.target kopia-server.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kopia-nas-sync.sh
Nice=19
IOSchedulingClass=2
IOSchedulingPriority=7
StandardOutput=append:/var/log/kopia/nas-sync.log
StandardError=append:/var/log/kopia/nas-sync-error.log

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/kopia-nas-sync.timer << EOF
[Unit]
Description=Kopia NAS sync timer

[Timer]
OnCalendar=${SERVER_SYNC_TIME:-*-*-* 05:00:00}
Persistent=true

[Install]
WantedBy=timers.target
EOF
}

# Initialize repository
init_repository() {
    log "Initializing Kopia repository..."
    if [ ! -f "${KOPIA_REPO_PATH}/.kopia" ]; then
        echo "${KOPIA_REPO_PASSWORD}" | kopia repository create filesystem \
            --path="${KOPIA_REPO_PATH}" \
            --cache-directory="${KOPIA_CACHE_DIR:-/var/cache/kopia}" \
            --max-cache-size="${KOPIA_CACHE_SIZE:-5G}"
    else
        log "Repository already exists, skipping creation"
    fi
}

# Main execution
main() {
    log "Starting Kopia server setup..."
    
    validate_env
    check_requirements
    setup_dirs
    check_nas
    mount_nas
    init_repository
    create_systemd_services

    log "Enabling and starting services..."
    systemctl daemon-reload
    systemctl enable kopia-server
    systemctl start kopia-server
    systemctl enable kopia-nas-sync.timer
    systemctl start kopia-nas-sync.timer

    # Verify services
    if ! systemctl is-active --quiet kopia-server; then
        log "ERROR: Failed to start kopia-server service"
        journalctl -u kopia-server --no-pager -n 50
        exit 1
    fi

    log "Kopia server setup completed successfully!"
    log "Server URL: ${KOPIA_SECURE_MODE:+https://}${KOPIA_SECURE_MODE:-http://}$(hostname -I | awk '{print $1}'):${KOPIA_SERVER_PORT}"
}

# Run main function
main "$@" 