#!/bin/bash
set -euo pipefail

# Find and load parent .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../" && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [ ! -f "${ENV_FILE}" ]; then
    echo "ERROR: .env file not found in ${ROOT_DIR}"
    exit 1
fi
source "${ENV_FILE}"

# Check NAS connectivity
check_nas() {
    log "INFO" "Checking NAS connectivity..."
    
    # Ping check
    if ! ping -c 1 -W 5 "${NAS_IP}" &>/dev/null; then
        echo '{"nas_status": 0, "message": "NAS unreachable"}'
        return
    fi

    # NFS export check
    if ! showmount -e "${NAS_IP}" | grep -q "${NAS_SHARE}"; then
        echo '{"nas_status": 1, "message": "Share unavailable"}'
        return
    fi

    # Mount point check
    if ! mountpoint -q "${NAS_MOUNT_PATH}"; then
        echo '{"nas_status": 2, "message": "Share not mounted"}'
        return
    fi

    # Write test
    if ! touch "${NAS_MOUNT_PATH}/.test_write" 2>/dev/null; then
        echo '{"nas_status": 3, "message": "Mount read-only"}'
        return
    fi
    rm -f "${NAS_MOUNT_PATH}/.test_write"

    echo '{"nas_status": 4, "message": "NAS OK"}'
}

# Check repository status
check_repository() {
    log "INFO" "Checking repository status..."
    
    local result
    result=$(docker exec "${KOPIA_CONTAINER_NAME}" kopia repository status --json 2>/dev/null) || {
        echo '{"repo_status": "error", "message": "Failed to get repository status"}'
        return
    }

    # Get repository info
    local repo_size
    repo_size=$(echo "$result" | jq -r '.size')
    
    local space_available
    space_available=$(df -B1 "${KOPIA_REPO_PATH}" | awk 'NR==2 {print $4}')

    # Check repository integrity
    local integrity
    integrity=$(docker exec "${KOPIA_CONTAINER_NAME}" kopia maintenance run --full --safety=full --json 2>/dev/null) || {
        echo '{"repo_status": "error", "message": "Integrity check failed"}'
        return
    }

    echo "{
        \"repo_status\": \"ok\",
        \"repo_size\": $repo_size,
        \"space_available\": $space_available,
        \"integrity\": $(echo "$integrity" | jq '.success')
    }"
}

# Check backup status
check_backup() {
    log "INFO" "Checking backup status..."
    
    local result
    result=$(docker exec "${KOPIA_CONTAINER_NAME}" kopia snapshot list --json 2>/dev/null) || {
        echo '{"backup_status": "error", "message": "Failed to get snapshots"}'
        return
    }

    local latest
    latest=$(echo "$result" | jq -r '[.[] | select(.type=="snapshot")] | sort_by(.startTime) | last // empty')
    
    if [ -z "$latest" ]; then
        echo '{"backup_status": "error", "message": "No snapshots found"}'
        return
    }

    local start_time
    start_time=$(echo "$latest" | jq -r '.startTime')
    local age_hours
    age_hours=$(( ($(date +%s) - $(date -d "$start_time" +%s)) / 3600 ))

    local validation_status
    validation_status=$(docker exec "${KOPIA_CONTAINER_NAME}" kopia snapshot verify \
        "$(echo "$latest" | jq -r '.id')" --json 2>/dev/null) || {
        echo '{"backup_status": "error", "message": "Validation failed"}'
        return
    }

    echo "{
        \"backup_status\": \"ok\",
        \"latest_backup\": \"$start_time\",
        \"age_hours\": $age_hours,
        \"validation\": $(echo "$validation_status" | jq '.success'),
        \"size\": $(echo "$latest" | jq '.stats.totalSize'),
        \"files\": $(echo "$latest" | jq '.stats.totalFiles')
    }"
}

# Enhanced logging
log() {
    local level="${1:-INFO}"
    local message="${2:-No message provided}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Main function to run all checks
main() {
    local check_type="${1:-all}"
    
    case "$check_type" in
        "nas")
            check_nas
            ;;
        "repository")
            check_repository
            ;;
        "backup")
            check_backup
            ;;
        "all")
            # Run all checks with delays between them
            echo "=== Starting complete system check ==="
            
            echo "=== NAS Check ==="
            check_nas
            sleep 20
            
            echo "=== Repository Check ==="
            check_repository
            sleep 20
            
            echo "=== Backup Check ==="
            check_backup
            ;;
        *)
            echo "Usage: $0 [all|nas|repository|backup]"
            exit 1
            ;;
    esac
}

# Run main with specified argument
main "${1:-all}" 