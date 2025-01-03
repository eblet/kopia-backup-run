# SSL Configuration Guide

Kopia server requires HTTPS/TLS for secure communication. This guide provides two options for setting up SSL:

## Option 1: Nginx with Let's Encrypt

### Prerequisites
- Domain name pointing to your server
- Port 80 and 443 available
- Docker and Docker Compose installed

### Setup Steps
1. Navigate to configs/ssl/nginx
2. Update domain name in nginx/conf.d/kopia.conf
3. Run initial setup:
```bash
docker-compose up -d
docker-compose run --rm certbot certonly --webroot -w /var/www/certbot -d your.domain.com
```

## Option 2: Traefik

### Prerequisites
- Domain name pointing to your server
- Port 443 available
- Docker and Docker Compose installed

### Setup Steps
1. Navigate to configs/ssl/traefik
2. Update email and domain in docker-compose.yml
3. Run:
```bash
docker-compose up -d
```

## Security Considerations
- Always use HTTPS in production
- Keep certificates up to date
- Regularly update Nginx/Traefik versions
- Use strong SSL configurations

For more details, see the official documentation:
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [Traefik HTTPS & SSL](https://doc.traefik.io/traefik/https/overview/) 