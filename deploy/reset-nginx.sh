#!/bin/bash

###############################################################################
# Script de Reset do Nginx - SincroApp
# Descrição: Atualiza configuração Nginx e recarrega serviço
###############################################################################

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Verificar root
if [ "$EUID" -ne 0 ]; then 
    log_error "Execute como root: sudo bash deploy/reset-nginx.sh"
    exit 1
fi

INSTALL_DIR="/var/www/webapp/sincroapp_flutter"
NGINX_CONFIG="/etc/nginx/sites-available/sincroapp.com.br"
NGINX_ENABLED="/etc/nginx/sites-enabled/sincroapp.com.br"

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  SINCROAPP - RESET CONFIGURAÇÃO NGINX${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"

# 1. Backup da configuração atual
if [ -f "$NGINX_CONFIG" ]; then
    BACKUP_FILE="$NGINX_CONFIG.bak.$(date +%Y%m%d_%H%M%S)"
    log_info "Fazendo backup: $BACKUP_FILE"
    cp "$NGINX_CONFIG" "$BACKUP_FILE"
    log_success "Backup criado"
fi

# 2. Escrever nova configuração
log_info "Escrevendo nova configuração em $NGINX_CONFIG..."

cat > "$NGINX_CONFIG" <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name sincroapp.com.br www.sincroapp.com.br;
    return 301 https://sincroapp.com.br$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name sincroapp.com.br www.sincroapp.com.br;

    # Certificados SSL
    ssl_certificate /etc/letsencrypt/live/sincroapp.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sincroapp.com.br/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    root /var/www/webapp/sincroapp_flutter/build/web;
    index landing.html index.html;

    access_log /var/log/nginx/sincroapp-access.log;
    error_log /var/log/nginx/sincroapp-error.log;

    # Rota raiz: landing
    location = / {
        try_files /landing.html =404;
    }

    # App Flutter em /app
    location = /app {
        return 301 /app/;
    }
    
    # Assets JS/CSS/WASM do app (DEVE VIR ANTES de location /app/)
    # CRÍTICO: Remove trailing slashes antes de processar
    location ~ ^/app/(.+)\.(js|css|wasm|json|map)/?$ {
        rewrite ^/app/(.*)/$ /app/$1 permanent;
        try_files $uri =404;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /app/ {
        # Remove $uri/ para evitar redirecionamentos 301 em rotas dinâmicas (ex: /app/login)
        # IMPORTANTE: index.html está na raiz do build (build/web/index.html), não em build/web/app/
        try_files $uri /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # Arquivos estáticos gerais
    location ~* \.(png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Landing HTML e scripts (sem cache para evitar versão antiga)
    location = /landing.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
        try_files /landing.html =404;
    }

    location ~* ^/(landing|firebase-config)\.js$ {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # Manifest/Service Worker
    location ~* (manifest\.json|flutter_service_worker\.js)$ {
        expires 1h;
        add_header Cache-Control "public";
    }

    # Segurança
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.tailwindcss.com https://www.gstatic.com https://unpkg.com https://www.google.com https://recaptchaenterprise.googleapis.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://unpkg.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' https://firestore.googleapis.com https://*.cloudfunctions.net wss://*.firebaseio.com https://identitytoolkit.googleapis.com https://recaptchaenterprise.googleapis.com https://www.gstatic.com https://www.google.com https://content-firebaseappcheck.googleapis.com; frame-src https://www.google.com; worker-src 'self' blob: https://www.google.com;" always;

    autoindex off;
    client_max_body_size 10M;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;
}
EOF

log_success "Configuração escrita"

# 3. Criar symlink se não existir
if [ ! -L "$NGINX_ENABLED" ]; then
    log_info "Criando symlink em sites-enabled..."
    ln -sf "$NGINX_CONFIG" "$NGINX_ENABLED"
    log_success "Symlink criado"
else
    log_info "Symlink já existe"
fi

# 4. Testar configuração
log_info "Testando configuração Nginx..."
if nginx -t; then
    log_success "Configuração válida ✓"
else
    log_error "Configuração inválida! Restaure o backup se necessário"
    exit 1
fi

# 5. Recarregar Nginx
log_info "Recarregando Nginx..."
systemctl reload nginx
log_success "Nginx recarregado ✓"

# 6. Verificar status
if systemctl is-active --quiet nginx; then
    log_success "Nginx está ativo e rodando ✓"
else
    log_error "Nginx não está ativo!"
    exit 1
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  NGINX RESETADO COM SUCESSO!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""

log_info "PRÓXIMOS PASSOS:"
echo -e "  1. Testar landing: ${BLUE}https://sincroapp.com.br${NC}"
echo -e "  2. Testar app: ${BLUE}https://sincroapp.com.br/app/#/login${NC}"
echo -e "  3. Verificar logs: ${BLUE}tail -f /var/log/nginx/error.log${NC}"
echo ""
