#!/bin/bash
set -euo pipefail

# Volumes configuration with descriptions
declare -A volumes
eval "volumes=${DOCKER_VOLUMES}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

setup_dirs() {
    log "Creating required directories..."
    mkdir -p "${KOPIA_CONFIG_DIR}"
    mkdir -p "${KOPIA_CACHE_DIR}"
    mkdir -p "/var/log/kopia"
}

# Check server connection
if ! docker run --rm \
    --name kopia-client-check \
    --network host \
    -v $HOME/.config/kopia:/app/config \
    -v $HOME/.cache/kopia:/app/cache \
    kopia/kopia:latest \
    repository status > /dev/null 2>&1; then
    
    log "Reconnecting to server..."
    docker run --rm \
        --name kopia-client-connect \
        --network host \
        -v $HOME/.config/kopia:/app/config \
        -v $HOME/.cache/kopia:/app/cache \
        kopia/kopia:latest \
        repository connect server \
        --url http://${KOPIA_SERVER_IP}:${KOPIA_SERVER_PORT} \
        --username ${KOPIA_SERVER_USERNAME} \
        --password ${KOPIA_SERVER_PASSWORD}
fi

# Process each volume
for path in "${!volumes[@]}"; do
    # Parse parameters
    IFS=',' read -r volume_name app_tag type_tag <<< "${volumes[$path]}"
    
    log "Starting backup for $path ($volume_name)"
    
    # Check if directory exists
    if [ ! -d "$path" ]; then
        log "ERROR: Directory $path does not exist, skipping"
        continue
    }
    
    # Run backup
    docker run --rm \
        --name "kopia-client-$volume_name" \
        --network host \
        -v "$path:/backup$path:ro" \
        -v $HOME/.config/kopia:/app/config \
        -v $HOME/.cache/kopia:/app/cache \
        kopia/kopia:latest \
        snapshot create "/backup$path" \
        --override-username="$volume_name" \
        --override-hostname="docker-volumes" \
        --tags="$app_tag,$type_tag" \
        --description="Backup of $path (${volumes[$path]})" \
        --compression=zstd-fastest \
        --parallel=${KOPIA_PARALLEL_CLIENT:-4}

    if [ $? -eq 0 ]; then
        log "Successfully created backup for $path"
        
        # Get latest snapshot ID
        latest_snapshot=$(docker run --rm \
            --name "kopia-client-list-$volume_name" \
            --network host \
            -v $HOME/.config/kopia:/app/config \
            -v $HOME/.cache/kopia:/app/cache \
            kopia/kopia:latest \
            snapshot list "/backup$path" --json | grep -o '"id":"[^"]*"' | tail -n1 | cut -d'"' -f4)
        
        if [ ! -z "$latest_snapshot" ]; then
            log "Verifying backup integrity for $path (snapshot: $latest_snapshot)"
            
            # Verify snapshot
            docker run --rm \
                --name "kopia-client-verify-$volume_name" \
                --network host \
                -v $HOME/.config/kopia:/app/config \
                -v $HOME/.cache/kopia:/app/cache \
                kopia/kopia:latest \
                snapshot verify "$latest_snapshot"
            
            if [ $? -eq 0 ]; then
                log "Backup verification successful for $path"
            else
                log "ERROR: Backup verification failed for $path"
            fi
        else
            log "ERROR: Could not find latest snapshot for $path"
        fi
    else
        log "ERROR: Failed to create backup for $path"
    fi
done

log "All operations completed"

main() {
    log "Starting Kopia client backup..."
    
    setup_dirs
    setup_logging
    validate_volumes_config
    check_server
    run_backup

    log "Backup process completed"
}