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
    # Ping check
    if ! ping -c 1 -W 5 "${NAS_IP}" &>/dev/null; then
        echo "0"  # NAS unreachable
        exit 0
    fi

    # NFS export check
    if ! showmount -e "${NAS_IP}" | grep -q "${NAS_SHARE}"; then
        echo "1"  # NAS reachable but share unavailable
        exit 0
    fi

    # Mount point check
    if ! mountpoint -q "${NAS_MOUNT_PATH}"; then
        echo "2"  # Share not mounted
        exit 0
    fi

    # Write test
    if ! touch "${NAS_MOUNT_PATH}/.test_write" 2>/dev/null; then
        echo "3"  # Mount read-only or permission issue
        exit 0
    fi
    rm -f "${NAS_MOUNT_PATH}/.test_write"

    echo "4"  # All checks passed
}

check_nas 