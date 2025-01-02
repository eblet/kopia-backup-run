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
        "KOPIA_SERVER_IP"
        "KOPIA_SERVER_PORT"
        "KOPIA_CONFIG_DIR"
        "KOPIA_CACHE_DIR"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log "ERROR: $var is not set"
            exit 1
        fi
    done

    # Validate port number
    if ! [[ "${KOPIA_SERVER_PORT}" =~ ^[0-9]+$ ]] || \
       [ "${KOPIA_SERVER_PORT}" -lt 1 ] || \
       [ "${KOPIA_SERVER_PORT}" -gt 65535 ]; then
        log "ERROR: Invalid KOPIA_SERVER_PORT value"
        exit 1
    fi
}

# Validate JSON configuration
validate_volumes_config() {
    log "Validating volumes configuration..."
    if ! command -v jq &> /dev/null; then
        log "ERROR: jq is required but not installed"
        exit 1
    fi

    if ! echo "${DOCKER_VOLUMES}" | jq empty; then
        log "ERROR: Invalid JSON in DOCKER_VOLUMES"
        exit 1
    fi

    # Check if paths exist and validate configuration
    for path in $(echo "${DOCKER_VOLUMES}" | jq -r 'keys[]'); do
        if [ ! -d "$path" ]; then
            log "ERROR: Directory $path does not exist"
            exit 1
        fi

        # Validate volume configuration
        volume_config=$(echo "${DOCKER_VOLUMES}" | jq -r ".[\"$path\"]")
        if ! echo "$volume_config" | jq -e '.name and .tags' > /dev/null; then
            log "ERROR: Invalid configuration for path $path. Required fields: name, tags"
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

# Run backup
run_backup() {
    log "Starting backup process..."
    
    # Sort volumes by priority
    local volumes_by_priority=$(echo "${DOCKER_VOLUMES}" | jq -r 'to_entries | sort_by(.value.priority // 999) | from_entries')
    
    # Create temporary compose file
    local temp_compose="docker-compose.client.generated.yml"
    cp docker/docker-compose.client.yml "${temp_compose}"

    # Add volume mounts
    echo "${volumes_by_priority}" | jq -r 'keys[]' | while read -r path; do
        volume_config=$(echo "${volumes_by_priority}" | jq -r ".[\"$path\"]")
        name=$(echo "${volume_config}" | jq -r '.name')
        tags=$(echo "${volume_config}" | jq -r '.tags[]' | tr '\n' ',' | sed 's/,$//')
        compression=$(echo "${volume_config}" | jq -r '.compression // "zstd-fastest"')
        
        log "Configuring backup for $path ($name)"
        echo "      - ${path}:${path}:ro" >> "${temp_compose}"
        
        # Run backup
        if ! docker-compose -f "${temp_compose}" run --rm kopia-backup \
            snapshot create "${path}" \
            --tags="${tags}" \
            --compression="${compression}" \
            --parallel="${KOPIA_PARALLEL_CLIENT}"; then
            log "ERROR: Backup failed for $path"
            rm "${temp_compose}"
            return 1
        fi

        # Verify backup if enabled
        if [ "${BACKUP_VERIFY:-true}" = "true" ]; then
            log "Verifying backup for $path"
            docker-compose -f "${temp_compose}" run --rm kopia-backup \
                snapshot verify "${path}" || {
                log "ERROR: Verification failed for $path"
                rm "${temp_compose}"
                return 1
            }
        fi
    done

    rm "${temp_compose}"
    return 0
}

# Verify backup integrity
verify_backup_integrity() {
    # Логика проверки
}

# Main execution
main() {
    log "Starting Kopia client backup..."
    
    validate_env
    setup_dirs
    validate_volumes_config
    check_server
    run_backup

    log "Backup process completed successfully"
}

# Run main function
main "$@"