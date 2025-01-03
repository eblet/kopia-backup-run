#!/bin/bash
set -euo pipefail

# Add verbose mode
VERBOSE=${VERBOSE:-false}

# Enhanced logging with colors and verbose support
log() {
    local level="${1:-INFO}"
    local message="${2:-No message provided}"
    local color=""
    case $level in
        "INFO") color="\033[0;32m" ;;
        "WARN") color="\033[1;33m" ;;
        "ERROR") color="\033[0;31m" ;;
        "PROMPT") color="\033[0;36m" ;;
        "DEBUG") 
            color="\033[0;35m"
            if [ "${VERBOSE}" != "true" ]; then
                return
            fi
            ;;
    esac
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}\033[0m"
}

prompt_user() {
    local message="$1"
    local default="${2:-}"
    local response
    
    if [ -n "$default" ]; then
        read -p "$(log "PROMPT" "$message [$default]: ")" response
        echo "${response:-$default}"
    else
        read -p "$(log "PROMPT" "$message: ")" response
        echo "$response"
    fi
}

prompt_password() {
    local message="$1"
    local password
    
    read -s -p "$(log "PROMPT" "$message: ")" password
    echo
    echo "$password"
}

setup_kopia_exporter() {
    log "INFO" "Setting up Kopia exporter..."

    # Add exporter to docker-compose.exporter.yml
    cat > docker/docker-compose.exporter.yml <<EOF
version: '3.8'

services:
  kopia-exporter:
    build: 
      context: ${PWD}/monitoring/exporters/kopia-exporter
      dockerfile: Dockerfile
    container_name: kopia-client-exporter
    volumes:
      - ${KOPIA_CONFIG_DIR:-~/.config/kopia}:/app/config:ro
      - ${KOPIA_CACHE_DIR:-~/.cache/kopia}:/app/cache:ro
      - ${KOPIA_LOG_DIR:-/var/log/kopia}:/app/logs:ro
    environment:
      - KOPIA_CONFIG_PATH=/app/config
      - KOPIA_CACHE_PATH=/app/cache
      - KOPIA_LOG_PATH=/app/logs
    ports:
      - "${KOPIA_EXPORTER_PORT:-9091}:9091"
    restart: unless-stopped
    labels:
      - "prometheus.io/scrape=true"
      - "prometheus.io/port=${KOPIA_EXPORTER_PORT:-9091}"
      - "prometheus.io/path=/metrics"

  node-exporter:
    image: prom/node-exporter:latest
    container_name: kopia-client-node-exporter
    command:
      - '--path.rootfs=/host'
    volumes:
      - /:/host:ro,rslave
    ports:
      - "${NODE_EXPORTER_PORT:-9100}:9100"
    restart: unless-stopped
    labels:
      - "prometheus.io/scrape=true"
      - "prometheus.io/port=${NODE_EXPORTER_PORT:-9100}"
      - "prometheus.io/path=/metrics"

networks:
  default:
    name: kopia_network
    external: true
EOF

    # Add systemd service for exporters
    cat > /etc/systemd/system/kopia-exporters.service <<EOF
[Unit]
Description=Kopia Client Exporters
After=docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=${PWD}
ExecStartPre=-/usr/bin/docker compose -f docker/docker-compose.exporter.yml down
ExecStart=/usr/bin/docker compose -f docker/docker-compose.exporter.yml up
ExecStop=/usr/bin/docker compose -f docker/docker-compose.exporter.yml down
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable kopia-exporters.service
    systemctl start kopia-exporters.service

    log "INFO" "Kopia exporter setup completed"
}

check_dependencies() {
    log "INFO" "Checking dependencies..."
    
    local required_packages=(
        "docker"
        "curl"
        "jq"
    )
    
    for package in "${required_packages[@]}"; do
        if ! command -v "$package" >/dev/null 2>&1; then
            log "ERROR" "$package is required but not installed"
            exit 1
        fi
    done

    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log "ERROR" "Docker daemon is not running"
        exit 1
    fi

    # Check if kopia_network exists
    if ! docker network inspect kopia_network >/dev/null 2>&1; then
        log "INFO" "Creating kopia_network..."
        docker network create kopia_network
    fi
}

connect_to_server() {
    local server_host
    local server_port
    local username
    local password
    local repo_password
    local compose_file="docker/docker-compose.client.yml"
    local protocol="http"
    local cache_dir="/app/cache-client"
    
    log "INFO" "Setting up connection to Kopia server..."
    
    # Get server details
    server_host=$(prompt_user "Enter Kopia server hostname/IP" "localhost")
    server_port=$(prompt_user "Enter Kopia server port" "51515")
    username=$(prompt_user "Enter username" "simpleadmin")
    password=$(prompt_password "Enter password")
    repo_password=$(prompt_password "Enter repository password")
    
    # Remove newlines from passwords
    password=$(echo -n "$password" | tr -d '\n')
    repo_password=$(echo -n "$repo_password" | tr -d '\n')
    
    # Test server connection and determine protocol
    log "DEBUG" "Testing connection to ${server_host}:${server_port}..."
    if curl -sk "https://${server_host}:${server_port}/api/v1/repo/status" >/dev/null; then
        protocol="https"
        log "DEBUG" "Server supports HTTPS"
    elif curl -s "http://${server_host}:${server_port}/api/v1/repo/status" >/dev/null; then
        protocol="http"
        log "DEBUG" "Server supports HTTP"
    else
        log "ERROR" "Cannot connect to Kopia server at ${server_host}:${server_port}"
        exit 1
    fi
    log "DEBUG" "Server connection test successful using ${protocol}"

    # Check if running on same machine as server
    if docker ps | grep -q "kopia-server"; then
        log "WARN" "Detected Kopia server on this machine, using separate cache directory"
        cache_dir="/app/cache-client"
    fi
    
    # Create docker-compose.client.yml
    log "DEBUG" "Creating ${compose_file}..."
    mkdir -p "$(dirname "${compose_file}")"
    
    cat > "${compose_file}" <<EOF
version: '3.8'

services:
  kopia-client:
    image: kopia/kopia:latest
    container_name: kopia-client
    environment:
      KOPIA_PASSWORD: "${repo_password}"
      KOPIA_SERVER_USERNAME: "${username}"
      KOPIA_SERVER_PASSWORD: "${password}"
      TZ: "UTC"
    volumes:
      - ${KOPIA_CONFIG_DIR:-~/.config/kopia}:/app/config:rw
      - ${KOPIA_CACHE_DIR:-~/.cache/kopia}:${cache_dir}:rw
      - ${KOPIA_LOG_DIR:-/var/log/kopia}:/app/logs:rw
    entrypoint: ["kopia"]
    command: [
      "repository",
      "connect",
      "server",
      "--url=${protocol}://${server_host}:${server_port}",
      "--password=${repo_password}",
      "--override-hostname=${KOPIA_CLIENT_HOSTNAME:-$(hostname)}",
      "--cache-directory=${cache_dir}"
    ]
    networks:
      - kopia_network
    restart: "no"

networks:
  kopia_network:
    external: true
EOF

    # Debug: show generated docker-compose.client.yml content
    log "DEBUG" "Generated docker-compose.client.yml content:"
    if [ "${VERBOSE}" = "true" ]; then
        cat "${compose_file}"
    fi

    # Create required directories with proper permissions
    log "DEBUG" "Creating required directories..."
    for dir in \
        "${KOPIA_CONFIG_DIR:-~/.config/kopia}" \
        "${KOPIA_CACHE_DIR:-~/.cache/kopia}" \
        "${KOPIA_LOG_DIR:-/var/log/kopia}"; do
        mkdir -p "$dir"
        chmod 700 "$dir"
        log "DEBUG" "Created directory $dir with permissions 700"
    done

    # Validate compose file
    log "DEBUG" "Validating docker-compose file..."
    if ! docker compose -f "${compose_file}" config >/dev/null 2>&1; then
        log "ERROR" "Invalid docker-compose configuration. Full error:"
        docker compose -f "${compose_file}" config
        exit 1
    fi
    log "DEBUG" "Docker compose validation successful"
    
    # Connect to repository using Docker
    log "INFO" "Connecting to repository..."
    log "DEBUG" "Running docker compose up..."
    if [ "${VERBOSE}" = "true" ]; then
        docker compose -f "${compose_file}" up --abort-on-container-exit
    else
        docker compose -f "${compose_file}" up --abort-on-container-exit >/dev/null 2>&1
    fi
        
    log "INFO" "Successfully connected to repository"
}

setup_backup_policies() {
    log "INFO" "Setting up backup policies..."
    
    # Ask for backup paths
    local backup_paths=()
    while true; do
        local path=$(prompt_user "Enter path to backup (or 'done' to finish)")
        [ "$path" = "done" ] && break
        backup_paths+=("$path")
    done
    
    # Ask for schedule
    local schedule=$(prompt_user "Enter backup schedule (e.g., '@daily', '@hourly', '0 */4 * * *')" "@daily")
    
    # Create snapshot policy for each path
    for path in "${backup_paths[@]}"; do
        log "INFO" "Creating policy for $path"
        docker run --rm \
            -v ${KOPIA_CONFIG_DIR:-~/.config/kopia}:/app/config:rw \
            -v ${KOPIA_CACHE_DIR:-~/.cache/kopia}:/app/cache:rw \
            -v ${path}:${path}:ro \
            kopia/kopia:latest \
            policy set "$path" \
            --compression=zstd \
            --snapshot-time-schedule="$schedule" \
            --keep-latest=30 \
            --keep-hourly=24 \
            --keep-daily=7 \
            --keep-weekly=4 \
            --keep-monthly=6
    done
    
    log "INFO" "Backup policies configured successfully"
}

verify_setup() {
    log "INFO" "Verifying setup..."
    
    # Check repository connection
    if ! docker run --rm \
        -v ${KOPIA_CONFIG_DIR:-~/.config/kopia}:/app/config:rw \
        -v ${KOPIA_CACHE_DIR:-~/.cache/kopia}:/app/cache:rw \
        kopia/kopia:latest \
        repository status >/dev/null 2>&1; then
        log "ERROR" "Repository connection failed"
        exit 1
    fi
    
    # Test backup
    local test_backup=$(prompt_user "Would you like to run a test backup? (yes/no)" "yes")
    if [[ "$test_backup" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        local test_path=$(prompt_user "Enter path for test backup" "/etc/hosts")
        docker run --rm \
            -v ${KOPIA_CONFIG_DIR:-~/.config/kopia}:/app/config:rw \
            -v ${KOPIA_CACHE_DIR:-~/.cache/kopia}:/app/cache:rw \
            -v ${test_path}:${test_path}:ro \
            kopia/kopia:latest \
            snapshot create "$test_path"
        log "INFO" "Test backup completed successfully"
    fi
}

main() {
    log "INFO" "Starting Kopia client setup..."
    
    # Show verbose status
    if [ "${VERBOSE}" = "true" ]; then
        log "DEBUG" "Verbose mode enabled"
    fi
    
    check_dependencies
    connect_to_server
    setup_backup_policies
    setup_kopia_exporter
    verify_setup
    
    log "INFO" "Kopia client setup completed successfully"
    log "INFO" "Metrics available at:"
    log "INFO" "- Kopia metrics: http://localhost:${KOPIA_EXPORTER_PORT:-9091}/metrics"
    log "INFO" "- Node metrics: http://localhost:${NODE_EXPORTER_PORT:-9100}/metrics"
}

# Run main with error handling
trap 'log "ERROR" "Script failed on line $LINENO"' ERR
main "$@"