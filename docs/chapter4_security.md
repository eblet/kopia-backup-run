# 🔐 Chapter 4: Security

## 📑 Table of Contents
- [Overview](#overview)
- [Authentication & Authorization](#authentication--authorization)
- [Encryption & TLS](#encryption--tls)
- [Network Security](#network-security)
- [Access Control](#access-control)
- [Monitoring Security](#monitoring-security)
- [Best Practices](#best-practices)

## 🎯 Overview

The security system provides comprehensive protection through:
- 🔒 Multi-layer authentication
- 🛡️ End-to-end encryption
- 🌐 Network isolation
- 📝 Audit logging
- 🔍 Security monitoring

## 🔑 Authentication & Authorization

### 🖥️ Kopia Server Authentication

```bash
# 👤 Basic Authentication
KOPIA_SERVER_USERNAME=admin
KOPIA_SERVER_PASSWORD=secure-password-here

# 🎟️ API Token Authentication
KOPIA_API_TOKEN=your-secure-token
KOPIA_TOKEN_LIFETIME=24h
```

### 📦 Repository Authentication
```bash
# 🔐 Repository Password
KOPIA_REPO_PASSWORD=strong-repository-password

# 🔑 Key-based Authentication
KOPIA_KEY_PATH=/path/to/key
KOPIA_KEY_PASSWORD=key-password
```

### 📊 Monitoring Stack Authentication

1. **📈 Prometheus**
```yaml
# prometheus.yml
basic_auth_users:
  admin: $PROMETHEUS_PASSWORD_HASH

tls_config:
  cert_file: /etc/prometheus/certs/prometheus.crt
  key_file: /etc/prometheus/certs/prometheus.key
  min_version: TLS13
```

2. **📊 Grafana**
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

3. **🔍 Zabbix**
```bash
# Zabbix Agent Configuration
TLSConnect=cert
TLSCAFile=/etc/zabbix/certs/ca.crt
TLSCertFile=/etc/zabbix/certs/agent.crt
TLSKeyFile=/etc/zabbix/certs/agent.key
```

## 🔒 Encryption & TLS

### 📜 Certificate Management

1. **🔐 Generate Self-Signed Certificates**
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

2. **🌟 Let's Encrypt Integration**
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

### 🔐 Component TLS Configuration

1. **💾 Kopia Server**
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

2. **📊 Monitoring Stack**
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

### 🌐 Web Server Configurations

Example configurations are available in `docs/conf`:

1. **🔒 Nginx SSL Configuration**
```bash
# Available at: docs/conf/nginx.conf
# Usage: Include in your nginx server block

# Example location:
location / {
    proxy_pass http://kopia-server:51515;
    include /etc/nginx/conf.d/ssl/ssl.conf;
}
```

2. **🔐 Traefik SSL Configuration**
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

## 🛡️ Network Security

### 🔥 Firewall Configuration
```bash
# Allow required ports
ufw allow 51515/tcp  # Kopia Server
ufw allow 9090/tcp   # Prometheus (internal only)
ufw allow 9091/tcp   # Kopia Exporter (internal only)
ufw allow 3000/tcp   # Grafana
ufw allow 10050/tcp  # Zabbix Agent
```

### 🌐 Network Isolation
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

[Continue with the rest of Chapter 4...] 