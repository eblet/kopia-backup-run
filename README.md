   KOPIA_UPLOAD_LIMIT=0         # Upload speed limit (0=unlimited)
   KOPIA_DOWNLOAD_LIMIT=0       # Download speed limit (0=unlimited)
   ```

5. Backup Configuration:
   ```bash
   # Volume configuration (JSON format)
   DOCKER_VOLUMES='{
       "/path/to/data": {
           "name": "app-data",
           "tags": ["type:data", "app:myapp"],
           "compression": "zstd-fastest",
           "exclude": ["*.tmp", "*.log"],
           "priority": 1
       }
   }'
Kopia Backup System 🚀

   # Backup settings
   BACKUP_COMPRESSION=zstd-fastest
   BACKUP_VERIFY=true
   BACKUP_RETENTION_DAYS=7
   ```

📊 Monitoring & Maintenance
-------------------------

1. Service Status:
   ```bash
   # Docker status
   docker ps
   docker logs kopia-server
======================

Enterprise-ready configuration for Kopia backup system with Docker support.

📋 Prerequisites
---------------------

1. System Requirements:
   - 2GB RAM minimum
   - 10GB free disk space
   docker logs kopia-client

   # System service status
   systemctl status kopia-server
   systemctl status kopia-nas-sync.timer
   ```

2. Logs:
   ```bash
   # View logs
   tail -f /var/log/kopia/server.log
   - Docker and docker-compose
   - NFS client utilities
   - jq for JSON processing

2. NAS Requirements:
   - NFS server enabled
   - Network access from Kopia server
   - Proper NFS exports configured

   Example NFS exports:
   ```bash
   # /etc/exports
   /volume1/backups    10.0.0.0/24(rw,sync,no_subtree_check)
   tail -f /var/log/kopia/nas-sync.log

   # Log locations
   - /var/log/kopia/server.log
   - /var/log/kopia/server-error.log
   - /var/log/kopia/nas-sync.log
   - /var/log/kopia/nas-sync-error.log
   ```

3. Security Requirements:
   - Minimum 16 characters for passwords
   - Minimum 8 characters for username
   - Optional TLS encryption
   - IP-based access control

📦 Installation
---------------------

1. 🐳 Docker Installation (Recommended)

   Server Setup:
   ```

3. Backup Verification:
   ```bash
   # List snapshots
   docker exec kopia-server kopia snapshot list

   # Verify specific snapshot
   docker exec kopia-server kopia snapshot verify <snapshot-id>
   ```

🔄 Recovery Operations
-------------------

1. List Snapshots:
   ```bash
   ```bash
   # Clone repository
   git clone https://github.com/yourusername/kopia-backup-run   
   cd kopia-backup-run

   # Install dependencies
   sudo apt update
   docker exec kopia-server kopia snapshot list
   ```

2. Restore Files:
   ```bash
   docker exec kopia-server kopia snapshot restore \
   sudo apt install -y docker.io docker-compose nfs-common jq

   # Configure environment
   cp .env.example .env
   nano .env

   # Create required directories
   sudo mkdir -p /var/lib/kopia /var/log/kopia
   sudo chmod 750 /var/lib/kopia /var/log/kopia

   # Start Kopia server
   docker-compose -f docker/docker-compose.server.yml up -d

   # Verify server status
   docker logs kopia-server
   ```

   Client Setup:
   ```bash
   # Configure environment
   cp .env.example .env
   nano .env

   # Create required directories
   mkdir -p ~/.config/kopia ~/.cache/kopia
   sudo mkdir -p /var/log/kopia

   # Start backup
   ./scripts/kopia_client_docker_run.sh
   ```

2. 💻 Script Installation

   Server Setup:
   ```bash
   sudo ./scripts/kopia_server_setup.sh
   ```

🔑 Configuration
---------------

1. Security Settings:
     --target=/path/to/restore \
     <snapshot-id>
   ```

🛠️ Advanced Configuration
-----------------------

1. TLS Security:
   ```bash
   # Enable TLS
   ```bash
   # Required security settings
   KOPIA_REPO_PASSWORD=          # Min 16 chars, required
   KOPIA_SERVER_USERNAME=        # Min 8 chars, required
   KOPIA_SERVER_PASSWORD=        # Min 16 chars, required
   KOPIA_SECURE_MODE=false      # Enable TLS (true/false)
   KOPIA_SERVER_ALLOWED_IPS=    # Allowed IP ranges
   KOPIA_SECURE_MODE=true
   ```

2. NAS Mount Options:
   ```bash
   NAS_MOUNT_OPTIONS="rw,sync,hard,intr,rsize=32768,wsize=32768,noatime"
   NAS_TIMEOUT=30
   ```
   ```

2. Network Settings:
   ```bash
   KOPIA_SERVER_IP=             # Server IP address
   KOPIA_SERVER_PORT=51515      # Server port
   NAS_IP=                      # NAS IP address
   NAS_SHARE=                   # NAS share path
   ```

3. Storage Configuration:

3. Resource Management:
   ```bash
   # Server limits
   KOPIA_SERVER_CPU_LIMIT=2
   KOPIA_SERVER_MEM_LIMIT=2G

   # Client limits
   KOPIA_CLIENT_CPU_LIMIT=4
   KOPIA_CLIENT_MEM_LIMIT=4G
   ```
   ```bash
   KOPIA_BASE_DIR=/var/lib/kopia     # Base directory
   KOPIA_REPO_PATH=/var/lib/kopia/repository  # Repository path
   KOPIA_CONFIG_DIR=~/.config/kopia  # Client config
   KOPIA_CACHE_DIR=~/.cache/kopia   # Cache directory

4. Log Rotation:
   ```bash
   LOG_MAX_SIZE=100M
   LOG_MAX_FILES=7
   ```

⚠️ Troubleshooting
----------------

1. Connection Issues:
   ```bash
   # Check NFS
   showmount -e ${NAS_IP}
   mountpoint -q ${NAS_MOUNT_PATH}
   KOPIA_CACHE_SIZE=5G              # Cache size limit
   ```

4. Performance Settings:
   ```bash
   KOPIA_PARALLEL_CLIENT=4      # Client parallel operations
   KOPIA_PARALLEL_SERVER=2      # Server parallel operations

   # Check server
   curl -v ${KOPIA_SECURE_MODE:+https://}${KOPIA_SECURE_MODE:-http://}${KOPIA_SERVER_IP}:${KOPIA_SERVER_PORT}
   ```

2. Permission Problems:
   ```bash
   ls -la ${KOPIA_BASE_DIR}
   KOPIA_UPLOAD_LIMIT=0         # Upload speed limit (0=unlimited)
   ls -la ${KOPIA_REPO_PATH}
   ls -la /var/log/kopia
   ```

3. Resource Issues:
   ```bash
   docker stats
   df -h
   KOPIA_DOWNLOAD_LIMIT=0       # Download speed limit (0=unlimited)
   ```

5. Backup Configuration:
   ```bash
   # Volume configuration (JSON format)
   DOCKER_VOLUMES='{
       "/path/to/data": {
           "name": "app-data",
   free -m
   ```

4. Common Errors:
   - "Repository not initialized": Check KOPIA_REPO_PASSWORD
   - "Cannot connect to server": Check network and KOPIA_SERVER_IP
   - "NFS mount failed": Verify NAS connectivity
           "tags": ["type:data", "app:myapp"],
   - "Permission denied": Check directory permissions
   - "Invalid JSON": Validate DOCKER_VOLUMES format