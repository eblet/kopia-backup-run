# SSL Configuration Guide

Kopia server requires HTTPS/TLS for secure communication. This guide provides two options for setting up SSL:

## Option 1: Nginx with Let's Encrypt

### Prerequisites
- Domain name pointing to your server
- Port 80 and 443 available
- Docker and Docker Compose installed

### Setup Steps
1. Create necessary directories:
```bash
mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/certs
mkdir -p /etc/letsencrypt
mkdir -p /var/www/certbot
```

2. Copy Nginx configuration:
```bash
cp docs/nginx.conf /etc/nginx/conf.d/kopia.conf
```

3. Update domain name in the configuration file

4. Run initial setup:
```bash
docker-compose -f docker/docker-compose.nginx.yml up -d
docker-compose run --rm certbot certonly --webroot -w /var/www/certbot -d your.domain.com
```

## Option 2: Traefik

### Prerequisites
- Domain name pointing to your server
- Port 443 available
- Docker and Docker Compose installed

### Setup Steps
1. Create Traefik configuration directory:
```bash
mkdir -p /etc/traefik
```

2. Copy Traefik configuration:
```bash
cp docs/traefik.yml /etc/traefik/traefik.yml
```

3. Update email and domain in the configuration

4. Run:
```bash
docker-compose -f docker/docker-compose.traefik.yml up -d
```

## Configuration Files
- Nginx configuration: [docs/nginx.conf](nginx.conf)
- Traefik configuration: [docs/traefik.yml](traefik.yml)

## Security Considerations
- Always use HTTPS in production
- Keep certificates up to date
- Regularly update Nginx/Traefik versions
- Use strong SSL configurations

For more details, see the official documentation:
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [Traefik HTTPS & SSL](https://doc.traefik.io/traefik/https/overview/)