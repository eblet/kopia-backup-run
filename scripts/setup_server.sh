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

# Required environment variables
REQUIRED_VARS=(
    "KOPIA_BASE_DIR"
    "KOPIA_REPO_PASSWORD"
    "KOPIA_SERVER_USERNAME"
    "KOPIA_SERVER_PASSWORD"
    "KOPIA_SERVER_IP"
    "NAS_IP"
    "NAS_SHARE"
    "NAS_MOUNT_PATH"
)

# Check required variables
check_required_vars() {
    log "INFO" "Validating environment variables..."
    local missing_vars=()
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        log "ERROR" "Missing required environment variables:"
        printf '%s\n' "${missing_vars[@]}"
        exit 1
    fi
}

# Enhanced logging with colors
log() {
    local level="${1:-INFO}"
    local message="${2:-No message provided}"
    local color=""
    case $level in
        "INFO") color="\033[0;32m" ;;
        "WARN") color="\033[1;33m" ;;
        "ERROR") color="\033[0;31m" ;;
    esac
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}\033[0m"
}

# Check dependencies
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

# Check system requirements
check_system_requirements() {
    log "INFO" "Checking system requirements..."
    
    # Install NFS client
    log "INFO" "Installing nfs-common..."
    apt-get update -qq
    apt-get install -y nfs-common
    log "INFO" "Found nfs-common version $(dpkg -s nfs-common | grep Version | cut -d ' ' -f 2)"
    
    # Install curl
    log "INFO" "Installing curl..."
    apt-get update -qq
    apt-get install -y curl
    log "INFO" "Found curl version $(dpkg -s curl | grep Version | cut -d ' ' -f 2)"
    curl --version | head -n 1 | cut -d ' ' -f 2

    # Check memory
    local available_memory=$(free -m | awk '/Mem:/ {print $7}')
    log "INFO" "Available memory: ${available_memory}MB"
    
    # Check disk space
    for dir in "/var/lib/kopia" "/var/log/kopia" "/mnt/nas"; do
        local available_space=$(df -m $(dirname $dir) | awk 'NR==2 {print $4}')
        log "INFO" "Available space for $dir: ${available_space}MB"
    done
}

# Create required directories
create_directories() {
    log "INFO" "Creating and configuring directories..."
    
    # Create directories with proper permissions
    for dir in \
        "${KOPIA_BASE_DIR}" \
        "${KOPIA_BASE_DIR}/repository" \
        "${NAS_MOUNT_PATH}" \
        "${KOPIA_LOG_DIR}" \
        "${KOPIA_CACHE_DIR:-~/.cache/kopia}"; do
        mkdir -p "$dir"
        chmod 750 "$dir"
        log "INFO" "Created directory $dir with permissions 750"
    done
}

# Initialize repository
initialize_repository() {
    log "INFO" "Checking existing repository..."
    
    # Check if repository exists
    if [ -d "${KOPIA_BASE_DIR}/repository" ] && [ -n "$(ls -A ${KOPIA_BASE_DIR}/repository)" ]; then
        log "WARN" "Repository already exists at ${KOPIA_BASE_DIR}/repository"
        read -p "Do you want to delete existing repository and create new one? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Removing existing repository..."
            rm -rf "${KOPIA_BASE_DIR}/repository"/*
            rm -rf "${KOPIA_CONFIG_DIR:-~/.config/kopia}"/*
            rm -rf "${KOPIA_CACHE_DIR:-~/.cache/kopia}"/*
        else
            log "INFO" "Keeping existing repository"
            return 0
        fi
    fi
    
    log "INFO" "Initializing Kopia repository..."
    
    # Create repository
    docker run --rm \
        -v ${KOPIA_BASE_DIR}:/app/data \
        -v ${KOPIA_CONFIG_DIR:-~/.config/kopia}:/app/config \
        -v ${KOPIA_CACHE_DIR:-~/.cache/kopia}:/app/cache \
        -e KOPIA_PASSWORD=${KOPIA_REPO_PASSWORD} \
        kopia/kopia:latest \
        repository create filesystem \
        --path=/app/data/repository \
        --cache-directory=/app/cache

    # Show cache info
    log "INFO" "Repository cache information:"
    docker run --rm \
        -v ${KOPIA_BASE_DIR}:/app/data \
        -v ${KOPIA_CONFIG_DIR:-~/.config/kopia}:/app/config \
        -v ${KOPIA_CACHE_DIR:-~/.cache/kopia}:/app/cache \
        -e KOPIA_PASSWORD=${KOPIA_REPO_PASSWORD} \
        kopia/kopia:latest \
        cache info

    # Validate repository
    log "INFO" "Validating repository..."
    docker run --rm \
        -v ${KOPIA_BASE_DIR}:/app/data \
        -v ${KOPIA_CONFIG_DIR:-~/.config/kopia}:/app/config \
        -v ${KOPIA_CACHE_DIR:-~/.cache/kopia}:/app/cache \
        -e KOPIA_PASSWORD=${KOPIA_REPO_PASSWORD} \
        kopia/kopia:latest \
        repository validate-provider

    # Add user to repository
    log "INFO" "Adding user to repository..."
    docker run --rm \
        -v ${KOPIA_BASE_DIR}:/app/data \
        -v ${KOPIA_CONFIG_DIR:-~/.config/kopia}:/app/config \
        -v ${KOPIA_CACHE_DIR:-~/.cache/kopia}:/app/cache \
        -e KOPIA_PASSWORD=${KOPIA_REPO_PASSWORD} \
        kopia/kopia:latest \
        server user add \
        --user=${KOPIA_SERVER_USERNAME:-admin} \
        --password=${KOPIA_SERVER_PASSWORD:-admin}

    # Check repository status
    log "INFO" "Checking repository status..."
    docker run --rm \
        -v ${KOPIA_BASE_DIR}:/app/data \
        -v ${KOPIA_CONFIG_DIR:-~/.config/kopia}:/app/config \
        -v ${KOPIA_CACHE_DIR:-~/.cache/kopia}:/app/cache \
        -e KOPIA_PASSWORD=${KOPIA_REPO_PASSWORD} \
        kopia/kopia:latest \
        repository status
}

# Create systemd services
create_systemd_services() {
    log "INFO" "Setting up systemd services..."

    # Create Kopia server service
    log "INFO" "Creating Kopia server systemd service..."
    cat > /etc/systemd/system/kopia-server.service <<EOF
[Unit]
Description=Kopia Backup Server
After=docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=${PWD}
ExecStartPre=-/usr/bin/docker compose -f docker/docker-compose.server.yml down
ExecStart=/usr/bin/docker compose -f docker/docker-compose.server.yml up
ExecStop=/usr/bin/docker compose -f docker/docker-compose.server.yml down
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Create NAS sync service
    log "INFO" "Creating NAS sync service..."
    cat > /etc/systemd/system/kopia-nas-sync.service <<EOF
[Unit]
Description=Kopia NAS Sync Service
After=kopia-server.service

[Service]
Type=oneshot
ExecStart=/usr/bin/docker exec kopia-server kopia repository sync
RemainAfterExit=yes
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Create NAS sync timer
    log "INFO" "Creating NAS sync timer..."
    cat > /etc/systemd/system/kopia-nas-sync.timer <<EOF
[Unit]
Description=Kopia NAS Sync Timer

[Timer]
# Run daily at 5 AM
OnCalendar=*-*-* 05:00:00
AccuracySec=1m
RandomizedDelaySec=30
Unit=kopia-nas-sync.service

[Install]
WantedBy=timers.target
EOF

    # Reload systemd and enable services
    log "INFO" "Reloading systemd and enabling services..."
    systemctl daemon-reload
    
    # Enable and start server
    log "INFO" "Enabling and starting Kopia server..."
    systemctl enable kopia-server.service
    systemctl start kopia-server.service || log "WARN" "Failed to start kopia-server.service"
    
    # Enable timer
    log "INFO" "Enabling NAS sync timer..."
    systemctl enable kopia-nas-sync.timer
    systemctl start kopia-nas-sync.timer || log "WARN" "Failed to start kopia-nas-sync.timer"

    # Create logrotate configuration
    log "INFO" "Creating logrotate configuration..."
    cat > /etc/logrotate.d/kopia <<EOF
/var/log/kopia/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
EOF

    # Create cleanup script
    log "INFO" "Creating cleanup script..."
    cat > /usr/local/bin/kopia-cleanup <<EOF
#!/bin/bash
find /var/log/kopia -name "*.log.*" -mtime +7 -delete
EOF
    chmod +x /usr/local/bin/kopia-cleanup

    # Check services status
    log "INFO" "Checking services status..."
    log "INFO" "Kopia server status:"
    systemctl status kopia-server.service --no-pager || true
    log "INFO" "NAS sync timer status:"
    systemctl status kopia-nas-sync.timer --no-pager || true
}

# Create Docker network
create_docker_network() {
    log "INFO" "Setting up Docker network..."
    
    # Check if network exists
    if docker network inspect kopia_network >/dev/null 2>&1; then
        log "INFO" "Network kopia_network already exists"
        # Remove network if it has incorrect labels
        if ! docker network inspect kopia_network | grep -q '"com.docker.compose.network": "kopia_network"'; then
            log "WARN" "Network has incorrect labels, recreating..."
            docker network rm kopia_network
            docker network create \
                --driver bridge \
                --label com.docker.compose.network=kopia_network \
                --label com.docker.compose.project=kopia \
                kopia_network
        fi
    else
        log "INFO" "Creating network kopia_network..."
        docker network create \
            --driver bridge \
            --label com.docker.compose.network=kopia_network \
            --label com.docker.compose.project=kopia \
            kopia_network
    fi
}

check_nfs_connection() {
    log "INFO" "Checking NFS connection..."
    
    # Check if NAS is reachable
    if ! ping -c 1 "${NAS_IP}" > /dev/null 2>&1; then
        log "ERROR" "Cannot reach NAS at ${NAS_IP}"
        return 1
    fi
    
    # Check if NFS port is available
    if ! nc -z -w5 "${NAS_IP}" 2049; then
        log "ERROR" "NFS port (2049) is not accessible on ${NAS_IP}"
        return 1
    fi
    
    # Check if mountpoint exists
    if [ ! -d "${NAS_MOUNT_PATH:-/mnt/nas}" ]; then
        log "ERROR" "Mount point ${NAS_MOUNT_PATH:-/mnt/nas} does not exist"
        return 1
    fi
    
    # Check if already mounted
    if mountpoint -q "${NAS_MOUNT_PATH:-/mnt/nas}"; then
        log "INFO" "NFS is already mounted at ${NAS_MOUNT_PATH:-/mnt/nas}"
        
        # Check write permissions
        if ! touch "${NAS_MOUNT_PATH:-/mnt/nas}/.kopia_test" 2>/dev/null; then
            log "ERROR" "Cannot write to NFS mount point"
            return 1
        fi
        rm -f "${NAS_MOUNT_PATH:-/mnt/nas}/.kopia_test"
        
        # Check available space
        local available_space=$(df -P "${NAS_MOUNT_PATH:-/mnt/nas}" | tail -1 | awk '{print $4}')
        if [ "${available_space}" -lt 1048576 ]; then  # Less than 1GB
            log "WARN" "Less than 1GB space available on NFS share"
        fi
        
        return 0
    fi
    
    log "ERROR" "NFS is not mounted"
    return 1
}

setup_nfs() {
    log "INFO" "Setting up NFS mount..."
    
    # Create mount point
    mkdir -p "${NAS_MOUNT_PATH:-/mnt/nas}"
    
    # Mount NFS with specific options
    if ! mount -t nfs -o vers=3,proto=tcp,nolock "${NAS_IP}:${NAS_SHARE}" "${NAS_MOUNT_PATH:-/mnt/nas}"; then
        log "ERROR" "Failed to mount NFS share"
        return 1
    fi
    
    # Add to fstab if not already there
    if ! grep -q "${NAS_IP}:${NAS_SHARE}" /etc/fstab; then
        echo "${NAS_IP}:${NAS_SHARE} ${NAS_MOUNT_PATH:-/mnt/nas} nfs vers=3,proto=tcp,nolock 0 0" >> /etc/fstab
        log "INFO" "Added NFS mount to fstab"
    fi
    
    # Verify mount with detailed check
    if ! check_nfs_connection; then
        log "ERROR" "NFS mount verification failed"
        return 1
    fi
    
    log "INFO" "NFS setup completed successfully"
}

# Main function
main() {
    log "INFO" "Starting Kopia server setup..."
    
    # Setup NFS before starting the server
    setup_nfs || {
        log "ERROR" "NFS setup failed"
        exit 1
    }
    
    # Run checks
    check_required_vars
    check_versions
    check_system_requirements
    
    # Setup
    create_directories
    create_docker_network
    initialize_repository
    create_systemd_services
    
    log "INFO" "Checking services status..."
    
    # Check Kopia server status
    log "INFO" "Kopia server status:"
    systemctl status kopia-server.service --no-pager || true
    
    # Check NAS sync timer status
    log "INFO" "NAS sync timer status:"
    systemctl status kopia-nas-sync.timer --no-pager || true
    
    # Start Kopia server
    log "INFO" "Starting Kopia server..."
    docker compose -f docker/docker-compose.server.yml up -d
    
    # Final NFS check
    if check_nfs_connection; then
        log "INFO" "NFS/NAS connection verified: ${NAS_IP}:${NAS_SHARE} mounted at ${NAS_MOUNT_PATH:-/mnt/nas}"
        log "INFO" "Available space: $(df -h ${NAS_MOUNT_PATH:-/mnt/nas} | awk 'NR==2 {print $4}')"
    else
        log "ERROR" "NFS/NAS connection check failed at final verification"
        exit 1
    fi
    
    log "INFO" "Kopia server setup completed successfully"
}

# Run main with error handling
trap 'log "ERROR" "Script failed on line $LINENO"' ERR
main "$@"