#!/bin/bash

# Load environment variables
source .env

# Configuration
KOPIA_REPO_PATH="${KOPIA_REPO_PATH::/repository}"
NAS_MOUNT_PATH="${NAS_MOUNT_PATH:/nas}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log "Please run as root"
    exit 1
fi

# Install required packages
log "Installing required packages..."
apt update
apt install -y kopia nfs-common

# Create required directories
log "Creating directories..."
mkdir -p $KOPIA_REPO_PATH
mkdir -p $NAS_MOUNT_PATH

# Mount NAS
log "Mounting NAS..."
if ! grep -q "$NAS_MOUNT_PATH" /etc/fstab; then
    echo "$NAS_IP:$NAS_SHARE    $NAS_MOUNT_PATH   nfs   defaults    0 0" >> /etc/fstab
fi
mount -a

# Initialize Kopia repository
log "Initializing Kopia repository..."
if [ ! -f "$KOPIA_REPO_PATH/.kopia" ]; then
    echo $KOPIA_REPO_PASSWORD | kopia repository create filesystem --path $KOPIA_REPO_PATH
else
    log "Repository already exists, skipping creation"
fi

# Create systemd service for Kopia server
log "Creating systemd service..."
cat > /etc/systemd/system/kopia-server.service << EOF
[Unit]
Description=Kopia Backup Server
After=network.target

[Service]
Type=simple
User=root
Environment=KOPIA_PASSWORD=$KOPIA_REPO_PASSWORD
Environment=HOME=/root
WorkingDirectory=/root
ExecStart=/usr/bin/kopia server start \
    --address 0.0.0.0:${KOPIA_SERVER_PORT} \
    --server-username ${KOPIA_SERVER_USERNAME} \
    --server-password ${KOPIA_SERVER_PASSWORD} \
    --insecure
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create NAS sync service and timer
log "Creating NAS sync service and timer..."
cat > /usr/local/bin/kopia-nas-sync.sh << EOF
#!/bin/bash

# Sync with NAS with maximum compression
kopia snapshot create \
    --source-path=$KOPIA_REPO_PATH \
    --target-path=$NAS_MOUNT_PATH/kopia-repo \
    --compression=zstd-max \
    --parallel=${KOPIA_PARALLEL_SERVER:-2} \
    --check-integrity=true

# Clean old backups in local storage
kopia snapshot list --source-path=$KOPIA_REPO_PATH --maxage=7d --delete
EOF

chmod +x /usr/local/bin/kopia-nas-sync.sh

cat > /etc/systemd/system/kopia-nas-sync.service << EOF
[Unit]
Description=Kopia NAS sync service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kopia-nas-sync.sh
Nice=19
IOSchedulingClass=2
IOSchedulingPriority=7

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/kopia-nas-sync.timer << EOF
[Unit]
Description=Kopia NAS sync timer

[Timer]
OnCalendar=${SERVER_SYNC_TIME:-*-*-* 05:00:00}
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start services
log "Enabling and starting services..."
systemctl daemon-reload
systemctl enable kopia-server
systemctl start kopia-server
systemctl enable kopia-nas-sync.timer
systemctl start kopia-nas-sync.timer

# Final checks
log "Performing final checks..."
systemctl status kopia-server --no-pager
systemctl status kopia-nas-sync.timer --no-pager

log "Kopia server setup completed!"
log "Server URL: http://$(hostname -I | awk '{print $1}'):${KOPIA_SERVER_PORT}"
log "Username: ${KOPIA_SERVER_USERNAME}"
log "Password: ${KOPIA_SERVER_PASSWORD}"
log "Repository password: ${KOPIA_REPO_PASSWORD}"
log "NAS sync scheduled for 05:00 AM daily" 