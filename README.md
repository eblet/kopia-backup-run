Kopia Backup Run Scripts 🚀
======================

Enterprise-ready configuration for Kopia backup system with Docker support.

📋 Prerequisites
---------------------

1. NAS Requirements:
   - NFS server enabled and configured
   - Network access from Kopia server to NAS
   - Proper NFS exports configured

   Example NFS exports:
   ```bash
   # /etc/exports
   /volume1/backups    10.0.0.0/24(rw,sync,no_subtree_check)
   ```

2. Server Requirements:
   - Docker and docker-compose installed
   - NFS client utilities
   - Network connectivity to NAS
   - 2GB RAM minimum
   - 2 CPU cores minimum

   Verify environment:
   ```bash
   # Install requirements
   sudo apt update
   sudo apt install -y docker.io docker-compose nfs-common

   # Test NFS connectivity
   showmount -e ${NAS_IP}
   
   # Verify Docker
   docker --version
   docker-compose --version
   ```

📦 Installation
---------------------

1. 🐳 Docker Installation (Recommended)

   Server Setup:
   ```bash
   # Clone repository
   git clone https://github.com/eblet/kopia-backup-run   
   cd kopia-backup-run

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

1. Security Configuration:
   ```bash
   # Required security settings
   KOPIA_REPO_PASSWORD=          # Min 16 chars, required
   KOPIA_SERVER_USERNAME=        # Min 8 chars, required
   KOPIA_SERVER_PASSWORD=        # Min 16 chars, required
   KOPIA_SECURE_MODE=false      # Enable TLS (true/false)
   ```

2. Network Settings:
   ```bash
   KOPIA_SERVER_IP=             # Server IP address
   KOPIA_SERVER_PORT=51515      # Server port
   NAS_IP=                      # NAS IP address
   NAS_SHARE=                   # NAS share path
   ```

3. Path Configuration:
   ```bash
   KOPIA_BASE_DIR=/var/lib/kopia     # Base directory for all Kopia data
   KOPIA_REPO_PATH=/var/lib/kopia/repository  # Full path to repository
   KOPIA_CONFIG_DIR=~/.config/kopia  # Client config directory
   KOPIA_CACHE_DIR=~/.cache/kopia   # Client cache directory
   NAS_MOUNT_PATH=/mnt/NAS          # NAS mount point
   ```

4. Resource Limits:
   ```bash
   KOPIA_PARALLEL_CLIENT=4      # Client parallel operations
   KOPIA_PARALLEL_SERVER=2      # Server parallel operations
   KOPIA_CLIENT_CPU_LIMIT=4     # Client CPU limit
   KOPIA_CLIENT_MEM_LIMIT=4G    # Client memory limit
   KOPIA_SERVER_CPU_LIMIT=2     # Server CPU limit
   KOPIA_SERVER_MEM_LIMIT=2G    # Server memory limit
   ```

5. Backup Configuration:
   ```bash
   # Volume configuration in JSON format
   DOCKER_VOLUMES='{
       "/path/to/data": {
           "name": "app-data",
           "tags": ["type:data", "app:myapp"],
           "compression": "zstd-fastest",
           "exclude": ["*.tmp", "*.log"]
       }
   }'

   # Backup settings
   BACKUP_COMPRESSION=zstd-fastest  # Compression algorithm
   BACKUP_VERIFY=true              # Verify after backup
   ```

📊 Monitoring & Maintenance
-------------------------

1. Check Service Status:
   ```bash
   # Docker installation
   docker ps
   docker logs kopia-server
   docker logs kopia-client

   # Check logs
   tail -f /var/log/kopia/server.log
   tail -f /var/log/kopia/client.log
   ```

2. Verify Backups:
   ```bash
   # List snapshots
   docker exec kopia-server kopia snapshot list

   # Check repository status
   docker exec kopia-server kopia repository status
   ```

🔄 Recovery Operations
-------------------

1. List Available Snapshots:
   ```bash
   docker exec kopia-server kopia snapshot list
   ```

2. Restore Files:
   ```bash
   # Restore specific snapshot
   docker exec kopia-server kopia snapshot restore \
     --target=/path/to/restore \
     <snapshot-id>
   ```

3. Verify Snapshot:
   ```bash
   docker exec kopia-server kopia snapshot verify <snapshot-id>
   ```

🛠️ Advanced Configuration
-----------------------

1. TLS Security:
   ```bash
   # Enable TLS in .env
   KOPIA_SECURE_MODE=true
   ```

2. Performance Tuning:
   - Compression options:
     - `zstd-fastest`: Fast compression, lower CPU usage
     - `zstd-default`: Balanced compression
     - `zstd-max`: Maximum compression, higher CPU usage
   
   - NFS optimization:
     ```bash
     NAS_MOUNT_OPTIONS="rw,sync,hard,intr,rsize=32768,wsize=32768"
     ```

3. Log Management:
   - Location: /var/log/kopia/
   - Automatic rotation: 7 days retention
   - Maximum size per file: 100MB

4. Resource Management:
   - Monitor usage: `docker stats kopia-server kopia-client`
   - Adjust limits in .env as needed
   - Check system resources: `htop` or `top`

⚠️ Troubleshooting
----------------

1. Connection Issues:
   ```bash
   # Check NFS mount
   showmount -e ${NAS_IP}
   mountpoint -q ${NAS_MOUNT_PATH}

   # Verify server connectivity
   curl -v http://${KOPIA_SERVER_IP}:${KOPIA_SERVER_PORT}
   ```

2. Permission Problems:
   ```bash
   # Check directory permissions
   ls -la ${KOPIA_BASE_DIR}
   ls -la ${KOPIA_REPO_PATH}
   ls -la /var/log/kopia
   ```

3. Resource Issues:
   ```bash
   # Check resource usage
   docker stats
   df -h
   free -m
   ```

4. Common Errors:
   - "Repository not initialized": Check KOPIA_REPO_PASSWORD
   - "Cannot connect to server": Verify network and KOPIA_SERVER_IP
   - "NFS mount failed": Check NAS connectivity and permissions
   - "Permission denied": Verify directory permissions