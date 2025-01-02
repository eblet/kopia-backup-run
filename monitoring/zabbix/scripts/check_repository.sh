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

# Check repository status
check_repository() {
    local result
    result=$(docker exec "${KOPIA_CONTAINER_NAME}" kopia repository status --json 2>/dev/null) || {
        echo '{"status": "error", "message": "Failed to get repository status"}'
        exit 0
    }

    # Get repository info
    local repo_size
    repo_size=$(echo "$result" | jq -r '.size')
    
    local space_available
    space_available=$(df -B1 "${KOPIA_REPO_PATH}" | awk 'NR==2 {print $4}')

    # Check repository integrity
    local integrity
    integrity=$(docker exec "${KOPIA_CONTAINER_NAME}" kopia maintenance run --full --safety=full --json 2>/dev/null) || {
        echo '{"status": "error", "message": "Integrity check failed"}'
        exit 0
    }

    # Prepare response
    echo "{
        \"status\": \"ok\",
        \"repo_size\": $repo_size,
        \"space_available\": $space_available,
        \"integrity\": $(echo "$integrity" | jq '.success')
    }"
}

check_repository 