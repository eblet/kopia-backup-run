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

# Get list of recent backups
get_recent_backups() {
    local result
    result=$(docker exec "${KOPIA_CONTAINER_NAME}" kopia snapshot list --json 2>/dev/null) || {
        echo "[]"
        return
    }
    
    echo "$result" | jq -r '
        [.[] | select(.type=="snapshot")] |
        sort_by(.startTime) |
        reverse |
        .[0:10] |
        map({
            time: .startTime,
            source: .source,
            size: .stats.totalSize,
            files: .stats.totalFiles,
            status: .incomplete // false,
            error: .error // null
        })
    '
}

# Check backup status
check_backup() {
    local result
    result=$(docker exec "${KOPIA_CONTAINER_NAME}" kopia snapshot list --json 2>/dev/null) || {
        echo '{"status": "error", "message": "Failed to get snapshots"}'
        exit 0
    }

    local latest
    latest=$(echo "$result" | jq -r '[.[] | select(.type=="snapshot")] | sort_by(.startTime) | last // empty')
    
    if [ -z "$latest" ]; then
        echo '{"status": "error", "message": "No snapshots found"}'
        exit 0
    }

    local start_time
    start_time=$(echo "$latest" | jq -r '.startTime')
    local age_hours
    age_hours=$(( ($(date +%s) - $(date -d "$start_time" +%s)) / 3600 ))

    local validation_status
    validation_status=$(docker exec "${KOPIA_CONTAINER_NAME}" kopia snapshot verify \
        "$(echo "$latest" | jq -r '.id')" --json 2>/dev/null) || {
        echo '{"status": "error", "message": "Validation failed"}'
        exit 0
    }

    echo "{
        \"status\": \"ok\",
        \"latest_backup\": \"$start_time\",
        \"age_hours\": $age_hours,
        \"validation\": $(echo "$validation_status" | jq '.success'),
        \"size\": $(echo "$latest" | jq '.stats.totalSize'),
        \"files\": $(echo "$latest" | jq '.stats.totalFiles')
    }"
}

check_backup 