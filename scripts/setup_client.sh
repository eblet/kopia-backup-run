#!/bin/bash
set -euo pipefail

# Enhanced logging with colors
log() {
    local level="${1:-INFO}"
    local message="${2:-No message provided}"
    local color=""
    case $level in
        "INFO") color="\033[0;32m" ;;
        "WARN") color="\033[1;33m" ;;
        "ERROR") color="\033[0;31m" ;;
        "PROMPT") color="\033[0;36m" ;;
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

check_dependencies() {
    log "INFO" "Checking dependencies..."
    
    local required_packages=(
        "kopia"
        "curl"
        "jq"
    )
    
    for package in "${required_packages[@]}"; do
        if ! command -v "$package" >/dev/null 2>&1; then
            log "ERROR" "$package is required but not installed"
            exit 1
        fi
    done
}

connect_to_server() {
    local server_host
    local server_port
    local username
    local password
    local repo_password
    
    log "INFO" "Setting up connection to Kopia server..."
    
    # Get server details
    server_host=$(prompt_user "Enter Kopia server hostname/IP" "localhost")
    server_port=$(prompt_user "Enter Kopia server port" "51515")
    username=$(prompt_user "Enter username")
    password=$(prompt_password "Enter password")
    repo_password=$(prompt_password "Enter repository password")
    
    # Test server connection
    if ! curl -s "http://${server_host}:${server_port}/api/v1/repo/status" >/dev/null; then
        log "ERROR" "Cannot connect to Kopia server at ${server_host}:${server_port}"
        exit 1
    fi
    
    # Connect to repository
    log "INFO" "Connecting to repository..."
    kopia repository connect server \
        --url="http://${server_host}:${server_port}" \
        --username="$username" \
        --password="$password" \
        --override-hostname="$(hostname)" \
        --password-file=<(echo "$repo_password")
        
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
    
    # Create snapshot policy
    for path in "${backup_paths[@]}"; do
        log "INFO" "Creating policy for $path"
        kopia policy set "$path" \
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

setup_monitoring() {
    log "INFO" "Setting up monitoring..."
    
    local setup_monitoring=$(prompt_user "Would you like to set up monitoring? (yes/no)" "yes")
    if [[ "$setup_monitoring" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        # Copy monitoring configuration
        cp .env.example .env
        
        # Get Zabbix server details
        ZABBIX_SERVER_HOST=$(prompt_user "Enter Zabbix server hostname")
        ZABBIX_SERVER_PORT=$(prompt_user "Enter Zabbix server port" "10051")
        KOPIA_CLIENT_HOSTNAME=$(prompt_user "Enter client hostname in Zabbix" "$(hostname)")
        
        # Update .env file
        sed -i "s/^ZABBIX_SERVER_HOST=.*/ZABBIX_SERVER_HOST=$ZABBIX_SERVER_HOST/" .env
        sed -i "s/^ZABBIX_SERVER_PORT=.*/ZABBIX_SERVER_PORT=$ZABBIX_SERVER_PORT/" .env
        sed -i "s/^KOPIA_CLIENT_HOSTNAME=.*/KOPIA_CLIENT_HOSTNAME=$KOPIA_CLIENT_HOSTNAME/" .env
        
        # Setup monitoring
        ./scripts/setup_monitoring.sh
    fi
}

verify_setup() {
    log "INFO" "Verifying setup..."
    
    # Check repository connection
    if ! kopia repository status >/dev/null 2>&1; then
        log "ERROR" "Repository connection failed"
        exit 1
    fi
    
    # Test backup
    local test_backup=$(prompt_user "Would you like to run a test backup? (yes/no)" "yes")
    if [[ "$test_backup" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        local test_path=$(prompt_user "Enter path for test backup" "/etc/hosts")
        kopia snapshot create "$test_path"
        log "INFO" "Test backup completed successfully"
    fi
}

main() {
    log "INFO" "Starting Kopia client setup..."
    
    check_dependencies
    connect_to_server
    setup_backup_policies
    setup_monitoring
    verify_setup
    
    log "INFO" "Kopia client setup completed successfully"
    log "INFO" "You can now use 'kopia snapshot create' to create backups"
}

# Run main with error handling
trap 'log "ERROR" "Script failed on line $LINENO"' ERR
main "$@"