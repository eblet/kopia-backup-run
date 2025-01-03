# 🔐 Chapter 4: Security

## Table of Contents
- [Overview](#overview)
- [Authentication & Authorization](#authentication--authorization)
- [Encryption & TLS](#encryption--tls)
- [Network Security](#network-security)
- [Access Control](#access-control)
- [Monitoring Security](#monitoring-security)
- [Best Practices](#best-practices)

## Overview

The security system provides comprehensive protection through:
- 🔒 Multi-layer authentication
- 🛡️ End-to-end encryption
- 🌐 Network isolation
- 📝 Audit logging
- 🔍 Security monitoring

## Authentication & Authorization

### Kopia Server Authentication

```bash
# Basic Authentication
KOPIA_SERVER_USERNAME=admin
KOPIA_SERVER_PASSWORD=secure-password-here

# API Token Authentication
KOPIA_API_TOKEN=your-secure-token
KOPIA_TOKEN_LIFETIME=24h
```

### Repository Authentication
```bash
# Repository Password
KOPIA_REPO_PASSWORD=strong-repository-password

# Key-based Authentication
KOPIA_KEY_PATH=/path/to/key
KOPIA_KEY_PASSWORD=key-password
```

### Monitoring Stack Authentication

1. **Prometheus**
```yaml
# prometheus.yml
basic_auth_users:
  admin: $PROMETHEUS_PASSWORD_HASH

tls_config:
  cert_file: /etc/prometheus/certs/prometheus.crt
  key_file: /etc/prometheus/certs/prometheus.key
  min_version: TLS13
```

2. **Grafana**
```ini
# grafana.ini
[security]
admin_user = admin
admin_password = ${GRAFANA_ADMIN_PASSWORD}
secret_key = ${GRAFANA_SECRET_KEY}
disable_gravatar = true
cookie_secure = true
allow_embedding = false
```

3. **Zabbix**
```bash
# Zabbix Agent Configuration
TLSConnect=cert
TLSCAFile=/etc/zabbix/certs/ca.crt
TLSCertFile=/etc/zabbix/certs/agent.crt
TLSKeyFile=/etc/zabbix/certs/agent.key
```

## Encryption & TLS

### Certificate Management

1. **Generate Self-Signed Certificates**
```bash
# Generate CA key and certificate
openssl genrsa -out ca.key 4096
openssl req -new -x509 -key ca.key -out ca.crt -days 365 \
    -subj "/CN=Kopia Backup CA"

# Generate server key and CSR
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr \
    -subj "/CN=kopia-server"

# Sign server certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt -days 365
```

2. **Let's Encrypt Integration**
```bash
# Install certbot
apt-get install certbot

# Generate certificates
certbot certonly --standalone \
    -d backup.yourdomain.com \
    --agree-tos \
    --email admin@yourdomain.com \
    --rsa-key-size 4096

# Auto-renewal setup
echo "0 0 1 * * root certbot renew --quiet" > /etc/cron.d/certbot-renew
```

### Component TLS Configuration

1. **Kopia Server**
```yaml
# docker-compose.yml
services:
  kopia-server:
    environment:
      - KOPIA_TLS_CERT_FILE=/certs/server.crt
      - KOPIA_TLS_KEY_FILE=/certs/server.key
      - KOPIA_TLS_CA_FILE=/certs/ca.crt
      - KOPIA_TLS_MIN_VERSION=TLS1.3
    volumes:
      - ./certs:/certs:ro
```

2. **Monitoring Stack**
```yaml
# TLS Configuration for all components
tls_config:
  min_version: TLS13
  cipher_suites:
    - TLS_AES_256_GCM_SHA384
    - TLS_CHACHA20_POLY1305_SHA256
  curves:
    - X25519
    - P-384
```

## Network Security

### Firewall Configuration
```bash
# Allow required ports
ufw allow 51515/tcp  # Kopia Server
ufw allow 9090/tcp   # Prometheus (internal only)
ufw allow 9091/tcp   # Kopia Exporter (internal only)
ufw allow 3000/tcp   # Grafana
ufw allow 10050/tcp  # Zabbix Agent
```

### Network Isolation
```yaml
# docker-compose.yml
networks:
  kopia_network:
    driver: bridge
    internal: true
    ipam:
      config:
        - subnet: 172.20.0.0/16
          ip_range: 172.20.0.0/24
    driver_opts:
      encrypt: "true"
```

### VPN Integration
```bash
# OpenVPN Configuration
OVPN_DATA=/opt/ovpn-data
docker run -v $OVPN_DATA:/etc/openvpn --rm kylemanna/openvpn \
    ovpn_genconfig -u udp://VPN.SERVERNAME.COM
```

### Web Server Configurations

Example configurations are available in `docs/conf`:

1. **Nginx SSL Configuration**
```bash
# Available at: docs/conf/nginx.conf
# Usage: Include in your nginx server block

# Example location:
location / {
    proxy_pass http://kopia-server:51515;
    include /etc/nginx/conf.d/ssl/ssl.conf;
}
```

2. **Traefik SSL Configuration**
```bash
# Available at: docs/conf/traefik.yml
# Usage: Include in your Traefik dynamic configuration

# Example service:
services:
  kopia:
    loadBalancer:
      servers:
        - url: http://kopia-server:51515
    # TLS configuration included from docs/conf/traefik/tls.yml
```

## Access Control

### Role-Based Access Control (RBAC)

1. **Grafana RBAC**
```yaml
# grafana_rbac.yaml
apiVersion: 1
roles:
  - name: "Backup Viewer"
    permissions:
      - action: "dashboards:read"
        scope: "dashboards:uid:*"
      - action: "datasources:query"
        scope: "datasources:*"
```

2. **API Access Control**
```yaml
# api_security.yml
rate_limiting:
  enabled: true
  rate: 100
  burst: 200
  
cors:
  allowed_origins:
    - https://trusted-domain.com
  allowed_methods:
    - GET
    - POST
  max_age: 3600
```

## Monitoring Security

### Security Monitoring

1. **Alert Rules**
```yaml
# security_alerts.yml
groups:
  - name: security_alerts
    rules:
      - alert: UnauthorizedAccess
        expr: rate(http_requests_total{status="401"}[5m]) > 10
        for: 5m
        labels:
          severity: critical
```

2. **Audit Logging**
```yaml
# audit_policy.yml
audit:
  enabled: true
  log_path: /var/log/audit
  max_age: 30
  max_backups: 10
  max_size: 100
```

## Best Practices

### Password Policies
- Minimum length: 16 characters
- Require complexity (uppercase, lowercase, numbers, symbols)
- Regular password rotation (90 days)
- Password history enforcement (last 12 passwords)
- Account lockout after 5 failed attempts

### Certificate Management
- Regular certificate rotation (90 days)
- Automated certificate renewal
- Certificate revocation procedures
- Strong key algorithms (RSA 4096 or ECC P-384)
- Secure key storage

### Network Security
- TLS 1.3 only
- Strong cipher suites
- Certificate pinning
- Weekly security scans
- Network segmentation

### Backup Security
- End-to-end encryption
- Secure key storage
- Regular backup validation
- Access control for restores
- Immutable backups

[Continue to Chapter 5: Maintenance →](chapter5_maintenance.md) 