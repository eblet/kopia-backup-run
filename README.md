# 🚀 Kopia Backup System

Enterprise-grade backup solution using Kopia with Docker support.

## 📋 System Requirements

### Server Requirements
- Docker Engine 20.10+
- Docker Compose 2.0+
- 2GB RAM minimum (4GB recommended)
- 2 CPU cores minimum
- 10GB free disk space
- NFS client utilities
- Network access to NAS

### Client Requirements
- Docker Engine 20.10+
- Docker Compose 2.0+
- 1GB RAM minimum
- Network access to Kopia server

## 🛠️ Quick Start

### Server Setup

1. Clone repository and configure environment:
```bash
git clone https://github.com/yourusername/kopia-backup
cd kopia-backup
cp .env.example .env
```

2. Edit configuration:
```bash
nano .env
```

3. Run server setup:
```bash
sudo ./scripts/kopia_server_setup.sh
```

### Client Setup

1. Configure environment:
```bash
cp .env.example .env
nano .env
```

2. Run backup:
```bash
./scripts/kopia_client_docker_run.sh
```

## 📝 Configuration Guide

### Essential Settings

1. Security Configuration:
```properties
KOPIA_REPO_PASSWORD=<strong-password>    # Min 16 characters
KOPIA_SERVER_USERNAME=<username>         # Min 8 characters
KOPIA_SERVER_PASSWORD=<strong-password>  # Min 16 characters
KOPIA_SECURE_MODE=true                  # Enable TLS
```

2. Network Settings:
```properties
KOPIA_SERVER_IP=192.168.1.100
KOPIA_SERVER_PORT=51515
KOPIA_SERVER_ALLOWED_IPS=192.168.1.0/24
```

3. Storage Configuration:
```properties
KOPIA_BASE_DIR=/var/lib/kopia
NAS_MOUNT_PATH=/mnt/nas
```

### Volume Configuration

Define backup volumes in JSON format:
```json
DOCKER_VOLUMES='{
    "/path/to/backup": {
        "name": "data-backup",
        "tags": ["prod", "data"],
        "compression": "zstd-fastest",
        "priority": 1
    }
}'
```

### Performance Tuning

1. Resource Limits:
```properties
KOPIA_CLIENT_CPU_LIMIT=4
KOPIA_CLIENT_MEM_LIMIT=4G
KOPIA_PARALLEL_CLIENT=4
```

2. Cache Settings:
```properties
KOPIA_CACHE_SIZE=5G
KOPIA_UPLOAD_LIMIT=0
KOPIA_DOWNLOAD_LIMIT=0
```

## 🔍 Monitoring

### Check Service Status
```bash
# Server status
docker logs kopia-server
systemctl status kopia-server

# Client logs
docker logs kopia-client
tail -f /var/log/kopia/client.log
```

### View Backups
```bash
# List snapshots
docker exec kopia-server kopia snapshot list

# Check repository
docker exec kopia-server kopia repository status
```

## 🔄 Recovery Operations

1. List Available Snapshots:
```bash
docker exec kopia-server kopia snapshot list
```

2. Restore Data:
```bash
docker exec kopia-server kopia snapshot restore \
  --target=/path/to/restore <snapshot-id>
```

## 🛟 Troubleshooting

### Common Issues

1. Connection Problems:
```bash
# Check NAS mount
mountpoint -q ${NAS_MOUNT_PATH}
showmount -e ${NAS_IP}

# Verify server
curl -v http://${KOPIA_SERVER_IP}:${KOPIA_SERVER_PORT}
```

2. Permission Issues:
```bash
# Check permissions
ls -la ${KOPIA_BASE_DIR}
ls -la /var/log/kopia
```

3. Resource Issues:
```bash
# Monitor resources
docker stats kopia-server kopia-client
df -h
free -m
```

## 🔒 Security Best Practices

1. Enable TLS:
```properties
KOPIA_SECURE_MODE=true
```

2. Set Strong Passwords:
- Use minimum 16 characters
- Include special characters
- Avoid common patterns

3. Restrict Access:
```properties
KOPIA_SERVER_ALLOWED_IPS=10.0.0.0/24,192.168.1.0/24
```

## 📚 Additional Resources

- [Kopia Documentation](https://kopia.io/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [NFS Setup Guide](https://help.ubuntu.com/community/NFSv4Howto)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.