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
        "KOPIA_SERVER_IP"
        "KOPIA_SERVER_PORT"
        "KOPIA_CONFIG_DIR"
        "KOPIA_CACHE_DIR"
        "DOCKER_VOLUMES"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log "ERROR: Required variable $var is not set"
            exit 1
        fi
    done

    # Validate password requirements
    if [[ ${#KOPIA_REPO_PASSWORD} -lt 16 ]]; then
        log "ERROR: KOPIA_REPO_PASSWORD must be at least 16 characters"
        exit 1
    fi

    if [[ ${#KOPIA_SERVER_PASSWORD} -lt 16 ]]; then
        log "ERROR: KOPIA_SERVER_PASSWORD must be at least 16 characters"
        exit 1
    fi

    # Validate port number
    if ! [[ "${KOPIA_SERVER_PORT}" =~ ^[0-9]+$ ]] || \
       [ "${KOPIA_SERVER_PORT}" -lt 1 ] || \
       [ "${KOPIA_SERVER_PORT}" -gt 65535 ]; then
        log "ERROR: Invalid KOPIA_SERVER_PORT value (must be between 1-65535)"
        exit 1
    fi
}

# Validate volumes configuration
validate_volumes_config() {
    log "Validating volumes configuration..."
    
    if ! command -v jq &> /dev/null; then
        log "ERROR: jq is required but not installed"
        exit 1
    fi

    # Validate JSON structure
    if ! echo "${DOCKER_VOLUMES}" | jq empty; then
        log "ERROR: Invalid JSON format in DOCKER_VOLUMES"
        exit 1
    }

    # Validate each volume configuration
    echo "${DOCKER_VOLUMES}" | jq -r 'to_entries[]' | while read -r volume; do
        local path=$(echo "$volume" | jq -r '.key')
        local config=$(echo "$volume" | jq -r '.value')

        # Check required fields
        if ! echo "$config" | jq -e '.name and .tags' > /dev/null; then
            log "ERROR: Volume $path missing required fields (name, tags)"
            exit 1
        fi

        # Validate path exists
        if [ ! -d "$path" ]; then
            log "ERROR: Directory $path does not exist"
            exit 1
        }

        # Validate compression if specified
        local compression=$(echo "$config" | jq -r '.compression // "zstd-fastest"')
        if [[ ! "$compression" =~ ^(zstd-fastest|zstd-default|zstd-max)$ ]]; then
            log "ERROR: Invalid compression setting for $path: $compression"
            exit 1
        fi
    done
}

# Setup directories
setup_dirs() {
    log "Creating required directories..."
    local dirs=(
        "${KOPIA_CONFIG_DIR}"
        "${KOPIA_CACHE_DIR}"
        "/var/log/kopia"
    )

    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            chmod 750 "$dir"
        fi
    done
}

# Check server connection
check_server() {
    local protocol="${KOPIA_SECURE_MODE:+https://}${KOPIA_SECURE_MODE:-http://}"
    local server_url="${protocol}${KOPIA_SERVER_IP}:${KOPIA_SERVER_PORT}"
    local max_retries=3
    local retry_delay=5

    log "Checking server connection at ${server_url}..."
    
    for ((i=1; i<=max_retries; i++)); do
        if curl -sf "${server_url}/api/v1/repo/status" &>/dev/null; then
            log "Server connection successful"
            return 0
        fi
        log "Connection attempt $i failed, retrying in ${retry_delay}s..."
        sleep "${retry_delay}"
    done

    log "ERROR: Cannot connect to Kopia server at ${server_url} after ${max_retries} attempts"
    exit 1
}

# Run backup process
run_backup() {
    log "Starting backup process..."
    
    local temp_compose="docker-compose.client.generated.yml"
    cp docker/docker-compose.client.yml "${temp_compose}"
    
    # Sort volumes by priority and process them
    echo "${DOCKER_VOLUMES}" | jq -r 'to_entries | sort_by(.value.priority // 999) | .[]' | \
    while read -r volume; do
        local path=$(echo "$volume" | jq -r '.key')
        local config=$(echo "$volume" | jq -r '.value')
        local name=$(echo "$config" | jq -r '.name')
        local tags=$(echo "$config" | jq -r '.tags | join(",")')
        local compression=$(echo "$config" | jq -r '.compression // "zstd-fastest"')
        
        log "Processing backup for $path ($name)"
        
        # Add volume mount to compose file
        echo "      - ${path}:${path}:ro" >> "${temp_compose}"
        
        # Execute backup
        if ! docker-compose -f "${temp_compose}" run --rm kopia-backup \
            snapshot create "${path}" \
            --tags="${tags}" \
            --compression="${compression}" \
            --parallel="${KOPIA_PARALLEL_CLIENT:-4}"; then
            log "ERROR: Backup failed for $path"
            cleanup_and_exit 1
        fi

        # Verify backup if enabled
        if [ "${BACKUP_VERIFY:-true}" = "true" ]; then
            log "Verifying backup for $path"
            if ! docker-compose -f "${temp_compose}" run --rm kopia-backup \
                snapshot verify "${path}"; then
                log "ERROR: Verification failed for $path"
                cleanup_and_exit 1
            fi
        fi
    done

    cleanup_and_exit 0
}

# Cleanup function
cleanup_and_exit() {
    local exit_code=$1
    rm -f docker-compose.client.generated.yml
    exit "${exit_code}"
}

# Verify backup integrity
verify_backup_integrity() {
    # Логика проверки
}

# Check system requirements
check_system_requirements() {
    log "Checking system requirements..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log "ERROR: Docker is not installed"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "ERROR: Docker Compose is not installed"
        exit 1
    fi

    # Check available disk space
    local required_space=5120  # 5GB in MB
    local available_space=$(df -m "${KOPIA_CONFIG_DIR}" | awk 'NR==2 {print $4}')
    if [ "${available_space}" -lt "${required_space}" ]; then
        log "WARNING: Less than 5GB free space available in ${KOPIA_CONFIG_DIR}"
    fi

    # Check memory
    local min_memory=1024  # 1GB in MB
    local available_memory=$(free -m | awk '/^Mem:/{print $2}')
    if [ "${available_memory}" -lt "${min_memory}" ]; then
        log "WARNING: System has less than 1GB RAM"
    fi
}

# Main execution
main() {
    log "Starting Kopia client backup process..."
    
    check_system_requirements
    validate_env
    setup_dirs
    validate_volumes_config
    check_server
    run_backup

    log "Backup process completed successfully"
}

# Trap for cleanup
trap 'cleanup_and_exit 1' INT TERM

# Run main function
main "$@"